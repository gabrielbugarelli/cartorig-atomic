#include "cartorig_renderer.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <stdexcept>
#include <utility>
#include <vector>

namespace cartorig {
namespace {

constexpr std::size_t kMaxPixels = 8192u * 8192u;

[[nodiscard]] double clamp01(double value) {
    return std::clamp(std::isfinite(value) ? value : 0.0, 0.0, 1.0);
}

[[nodiscard]] std::uint8_t byte(double normalized) {
    return static_cast<std::uint8_t>(std::lround(clamp01(normalized) * 255.0));
}

void composite(Raster& image, int x, int y, Color color, double opacity) {
    if (x < 0 || y < 0 || x >= image.width || y >= image.height) return;
    const double sourceAlpha = clamp01(color.alpha) * clamp01(opacity);
    if (sourceAlpha <= 0.0) return;
    const std::size_t index = 4u * (static_cast<std::size_t>(y) * image.width + x);
    const double backgroundAlpha = image.rgba[index + 3] / 255.0;
    const double finalAlpha = sourceAlpha + backgroundAlpha * (1.0 - sourceAlpha);
    const double components[] = {color.red,color.green,color.blue};
    for (int channel = 0; channel < 3; ++channel) {
        const double background = image.rgba[index + channel] / 255.0;
        const double numerator = clamp01(components[channel]) * sourceAlpha +
                                 background * backgroundAlpha * (1.0 - sourceAlpha);
        image.rgba[index + channel] = byte(finalAlpha > 0.0 ? numerator / finalAlpha : 0.0);
    }
    image.rgba[index + 3] = byte(finalAlpha);
}

void dot(Raster& image, double centerX, double centerY, double radius, Color color,
         double opacity) {
    if (!std::isfinite(centerX) || !std::isfinite(centerY) ||
        !std::isfinite(radius) || radius <= 0.0) return;
    if (centerX + radius < 0 || centerY + radius < 0 ||
        centerX - radius >= image.width || centerY - radius >= image.height) return;
    const int left = std::max(0, static_cast<int>(std::floor(centerX-radius)));
    const int right = std::min(image.width-1, static_cast<int>(std::ceil(centerX+radius)));
    const int top = std::max(0, static_cast<int>(std::floor(centerY-radius)));
    const int bottom = std::min(image.height-1, static_cast<int>(std::ceil(centerY+radius)));
    const double squared = radius * radius;
    for (int y=top; y<=bottom; ++y)
        for (int x=left; x<=right; ++x) {
            const double dx = x + 0.5 - centerX, dy = y + 0.5 - centerY;
            if (dx*dx+dy*dy <= squared) composite(image,x,y,color,opacity);
        }
}

void strokeLine(Raster& image, ScreenPoint a, ScreenPoint b, double width,
                Color color, double opacity) {
    if (width <= 0 || opacity <= 0) return;
    const double dx=b.x-a.x, dy=b.y-a.y;
    const double distance=std::hypot(dx,dy);
    if (!std::isfinite(distance)) return;
    const int count=std::max(1,static_cast<int>(std::ceil(std::min(distance,100000.0))));
    for(int i=0;i<=count;++i) {
        const double t=static_cast<double>(i)/count;
        dot(image,a.x+t*dx,a.y+t*dy,std::max(0.5,width/2.0),color,opacity);
    }
}

using ScreenRing = std::vector<ScreenPoint>;
using ScreenPolygon = std::vector<ScreenRing>;

[[nodiscard]] ScreenPolygon projectPolygon(
    const Polygon& polygon, CameraPose camera, int width, int height) {
    ScreenPolygon result;
    result.reserve(polygon.rings.size());
    for (const auto& ring : polygon.rings) {
        ScreenRing out;
        out.reserve(ring.size());
        for (const auto& point : ring) out.push_back(viewPosition(point,camera,width,height));
        result.push_back(std::move(out));
    }
    return result;
}

void fillEvenOdd(Raster& image, const ScreenPolygon& polygon,
                 Color color, double opacity) {
    if (polygon.empty()) return;
    double minY = std::numeric_limits<double>::infinity();
    double maxY = -std::numeric_limits<double>::infinity();
    for (const auto& ring : polygon) for (const auto& p : ring) {
        minY=std::min(minY,p.y);
        maxY=std::max(maxY,p.y);
    }
    if (!std::isfinite(minY) || !std::isfinite(maxY) ||
        maxY < 0.0 || minY >= image.height) return;
    const int top=std::max(0,static_cast<int>(std::floor(std::max(minY,-1.0))));
    const int bottom=std::min(image.height-1,static_cast<int>(
        std::ceil(std::min(maxY,static_cast<double>(image.height)))));
    std::vector<double> intersections;
    for (int y=top;y<=bottom;++y) {
        const double scanY=y+0.5;
        intersections.clear();
        for (const auto& ring : polygon) {
            if (ring.size() < 4) continue;
            for (std::size_t i=1;i<ring.size();++i) {
                const auto a=ring[i-1],b=ring[i];
                if ((a.y<=scanY && b.y>scanY) || (b.y<=scanY && a.y>scanY)) {
                    const double t=(scanY-a.y)/(b.y-a.y);
                    intersections.push_back(a.x+t*(b.x-a.x));
                }
            }
        }
        std::sort(intersections.begin(),intersections.end());
        for (std::size_t i=0;i+1<intersections.size();i+=2) {
            if (intersections[i+1] <= 0.0 || intersections[i] >= image.width) continue;
            const int left=std::max(0,static_cast<int>(
                std::ceil(std::max(intersections[i],-1.0)-0.5)));
            const int right=std::min(image.width-1,static_cast<int>(
                std::floor(std::min(intersections[i+1],static_cast<double>(image.width)+1)-0.5)));
            for (int x=left;x<=right;++x) composite(image,x,y,color,opacity);
        }
    }
}

void drawPolygon(Raster& image, const Polygon& polygon, CameraPose camera,
                 const Style& style, bool borders) {
    if (!style.visible || style.opacity <= 0.0) return;
    const auto screen=projectPolygon(polygon,camera,image.width,image.height);
    fillEvenOdd(image,screen,style.fill,style.opacity);
    if (borders && style.strokeWidthPixels > 0) {
        for (const auto& ring : screen)
            for (std::size_t i=1;i<ring.size();++i)
                strokeLine(image,ring[i-1],ring[i],style.strokeWidthPixels,
                           style.stroke,style.opacity);
    }
}

void drawFeature(Raster& image, const Feature& feature, CameraPose camera,
                 const Style& style, bool borders) {
    for (const auto& polygon : feature.polygons) {
        drawPolygon(image,polygon,camera,style,borders);
    }
}

void drawRoute(Raster& image, const Route& route, CameraPose camera) {
    if (!route.style.visible || route.style.opacity <= 0 || route.reveal <= 0) return;
    const auto start=viewPosition(route.from,camera,image.width,image.height);
    const auto end=viewPosition(route.to,camera,image.width,image.height);
    const double reveal=std::clamp(route.reveal,0.0,1.0);
    const ScreenPoint tip{start.x+(end.x-start.x)*reveal,
                          start.y+(end.y-start.y)*reveal};
    const double width=std::max(1.0,route.style.strokeWidthPixels);
    strokeLine(image,start,tip,width,route.style.stroke,route.style.opacity);
    const double dx=tip.x-start.x,dy=tip.y-start.y;
    const double length=std::hypot(dx,dy);
    if(length < 1e-6) return;
    const double unitX=dx/length,unitY=dy/length;
    const double back=std::max(8.0,4.0*width);
    const double side=std::max(5.0,2.25*width);
    const ScreenPoint left{tip.x-back*unitX-side*unitY,
                           tip.y-back*unitY+side*unitX};
    const ScreenPoint right{tip.x-back*unitX+side*unitY,
                            tip.y-back*unitY-side*unitX};
    strokeLine(image,tip,left,width,route.style.stroke,route.style.opacity);
    strokeLine(image,tip,right,width,route.style.stroke,route.style.opacity);
}

} // namespace

std::array<std::uint8_t,4> Raster::pixel(int x,int y) const {
    if(x<0 || y<0 || x>=width || y>=height)
        throw std::out_of_range("pixel outside raster");
    const auto pos=4u*(static_cast<std::size_t>(y)*width+x);
    return {rgba[pos],rgba[pos+1],rgba[pos+2],rgba[pos+3]};
}

Raster renderMap(const Catalog& catalog,const MapScene& scene,int width,int height,
                 const RenderOptions& options) {
    if(width<=0 || height<=0 ||
       static_cast<std::size_t>(width)*static_cast<std::size_t>(height)>kMaxPixels)
        throw std::invalid_argument("invalid or oversized render dimensions");
    Raster result;
    result.width=width;
    result.height=height;
    result.rgba.resize(4u*static_cast<std::size_t>(width)*height);
    for(std::size_t i=0;i<result.rgba.size();i+=4) {
        result.rgba[i] = byte(options.water.red);
        result.rgba[i+1] = byte(options.water.green);
        result.rgba[i+2] = byte(options.water.blue);
        result.rgba[i+3] = byte(options.water.alpha);
    }
    const auto camera=scene.camera();
    if(options.drawWorldLand) {
        for(const auto& feature:catalog.features()) {
            if(feature.type == LocationType::Country)
                drawFeature(result,feature,camera,options.land,options.drawBoundaries);
        }
    }
    for(const auto& region:scene.regions()) {
        const auto* feature=catalog.find(region.featureId);
        if(feature) drawFeature(result,*feature,camera,region.style,options.drawBoundaries);
    }
    for(const auto& route:scene.routes()) drawRoute(result,route,camera);
    return result;
}

} // namespace cartorig
