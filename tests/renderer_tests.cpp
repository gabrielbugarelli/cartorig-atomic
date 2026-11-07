#include "cartorig_core.hpp"
#include "cartorig_renderer.hpp"

#include <cmath>
#include <iostream>
#include <stdexcept>

using namespace cartorig;

namespace {
int assertions = 0;

void require(bool condition, const char* why) {
    ++assertions;
    if (!condition) throw std::runtime_error(why);
}

Polygon box(double west, double south, double east, double north) {
    Polygon p;
    p.rings.push_back({
        {west,south},{east,south},{east,north},{west,north},{west,south}
    });
    return p;
}

Catalog makeCatalog() {
    Catalog c;
    Feature land;
    land.id="country"; land.type=LocationType::Country; land.name="Country";
    land.country="Country";
    land.polygons={box(-20,-12,20,12)};
    c.add(land);

    Feature left;
    left.id="left"; left.type=LocationType::State; left.name="Left";
    left.parent="Country";left.country="Country";
    left.polygons={box(-10,-5,-0.05,5)};
    c.add(left);

    Feature right;
    right.id="right";right.type=LocationType::State;right.name="Right";
    right.parent="Country";right.country="Country";
    right.polygons={box(0.05,-5,10,5)};
    c.add(right);

    Feature city;
    city.id="origin";city.type=LocationType::City;city.name="Origin";
    city.country="Country";city.point=GeoPoint{-7,0};
    c.add(city);
    return c;
}

void testTrueGeographicPixels() {
    auto catalog=makeCatalog();
    MapScene scene({{0,0},5});
    require(static_cast<bool>(scene.addRegion(catalog,"a","left")),"region A add");
    require(static_cast<bool>(scene.addRegion(catalog,"b","right")),"region B add");

    Style a,b;
    a.fill={0.02,0.04,1.0,1.0};a.strokeWidthPixels=0;
    b.fill={0.02,1.0,0.04,1.0};b.strokeWidthPixels=0;
    require(static_cast<bool>(scene.setRegionStyle("a",a)),"style A");
    require(static_cast<bool>(scene.setRegionStyle("b",b)),"style B");
    RenderOptions options;
    options.drawBoundaries=false;
    const auto frame=renderMap(catalog,scene,200,100,options);
    require(frame.rgba.size()==200u*100u*4u,"frame RGBA stride");
    auto at=[&](double lon,double lat) {
        const auto p=viewPosition({lon,lat},scene.camera(),200,100);
        return frame.pixel(static_cast<int>(p.x),static_cast<int>(p.y));
    };
    const auto left=at(-5,0),right=at(5,0),land=at(15,0),ocean=at(30,0);
    require(left[2] > 220 && left[1] < 30,"left region blue via real projection");
    require(right[1] > 220 && right[2] < 30,"right region green independently");
    require(land[1] > land[2],"base country fill rendered");
    require(ocean[2] > ocean[1],"water background rendered");
    require(left[3] == 255 && right[3] == 255,"opaque expected output");

    a.fill={1,0,0,1};
    require(static_cast<bool>(scene.setRegionStyle("a",a)),"change only A");
    const auto changed=renderMap(catalog,scene,200,100,options);
    const auto pLeft=viewPosition({-5,0},scene.camera(),200,100);
    const auto pRight=viewPosition({5,0},scene.camera(),200,100);
    auto red=changed.pixel(static_cast<int>(pLeft.x),static_cast<int>(pLeft.y));
    auto stillGreen=changed.pixel(static_cast<int>(pRight.x),static_cast<int>(pRight.y));
    require(red[0] > 240 && red[2] < 10, "A became red");
    require(stillGreen==right,"B pixels unchanged by A style update");
}

void testRouteRevealAndCamera() {
    auto catalog=makeCatalog();
    MapScene scene({{0,0},5});
    RenderOptions options; options.drawBoundaries=false;
    require(static_cast<bool>(scene.addRoute(catalog,"route","origin","right",GeoPoint{5,0})),
            "endpoint explicitly located within target polygon");
    require(static_cast<bool>(scene.setRouteReveal("route",0)), "reveal progress zero");
    const auto before=renderMap(catalog,scene,200,100,options);

    Style paint;
    paint.stroke={1,0.92,0.01,1};
    paint.strokeWidthPixels=3;
    require(static_cast<bool>(scene.setRouteStyle("route",paint)),"style route");
    require(static_cast<bool>(scene.setRouteReveal("route",1)),"reveal progress one");
    const auto after=renderMap(catalog,scene,200,100,options);
    const auto p=viewPosition({-3,0},scene.camera(),200,100);
    const auto x=static_cast<int>(p.x), y=static_cast<int>(p.y);
    require(before.pixel(x,y)!=after.pixel(x,y),"revealed route modifies real pixels");

    require(scene.setRouteReveal("route",1.5).error==SceneError::InvalidValue,
            "reveal outside zero to one rejected");
    const auto old=scene.camera();
    const auto initialFrom=viewPosition(scene.routes()[0].from,old,200,100);
    const auto initialTo=viewPosition(scene.routes()[0].to,old,200,100);
    auto pose=old;pose.scale*=1.5;
    require(static_cast<bool>(scene.setCamera(pose)),"move shared camera");
    const auto zoomedFrom=viewPosition(scene.routes()[0].from,pose,200,100);
    const auto zoomedTo=viewPosition(scene.routes()[0].to,pose,200,100);
    require(std::abs((zoomedTo.x-zoomedFrom.x)-1.5*(initialTo.x-initialFrom.x))<1e-7,
            "geographic route anchors do not drift under camera zoom");
}

void testRasterBounds() {
    auto catalog=makeCatalog();
    MapScene scene;
    bool thrown=false;
    try { auto frame=renderMap(catalog,scene,-1,1);(void)frame; }
    catch(const std::invalid_argument&) {thrown=true;}
    require(thrown,"negative dimensions rejected");
    thrown=false;
    try { auto frame=renderMap(catalog,scene,9000,9000);(void)frame; }
    catch(const std::invalid_argument&) {thrown=true;}
    require(thrown,"unbounded frame allocation rejected");
}
}

int main() {
    try {
        testTrueGeographicPixels();
        testRouteRevealAndCamera();
        testRasterBounds();
        std::cout<<"PASS: "<<assertions<<" renderer assertions (native RGBA core)\n";
        return 0;
    } catch(const std::exception& e) {
        std::cerr<<"FAIL: "<<e.what()<<" at assertion "<<assertions<<"\n";
        return 1;
    }
}
