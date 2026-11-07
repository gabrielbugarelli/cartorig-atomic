#include "cartorig_core.hpp"

#include <cmath>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

using namespace cartorig;

namespace {
int checks = 0;

void check(bool condition, const char* description) {
    ++checks;
    if (!condition) throw std::runtime_error(description);
}

Polygon rectangle(double left, double bottom, double right, double top) {
    return {{{{left,bottom},{right,bottom},{right,top},{left,top},{left,bottom}}}};
}

Catalog populatedCatalog() {
    Catalog catalog;

    Feature brazil;
    brazil.id = "ne:country:br";
    brazil.type = LocationType::Country;
    brazil.name = "Brazil";
    brazil.country = "Brazil";
    brazil.aliases = {"Brasil"};
    brazil.polygons = {rectangle(-74,-34,-34,5)};
    catalog.add(std::move(brazil));

    Feature rioState;
    rioState.id = "ne:state:rj";
    rioState.type = LocationType::State;
    rioState.name = "Rio de Janeiro";
    rioState.parent = "Brazil";
    rioState.country = "Brazil";
    rioState.polygons = {rectangle(-45,-24,-40,-20)};
    catalog.add(std::move(rioState));

    Feature rioCity;
    rioCity.id = "ne:city:rio";
    rioCity.type = LocationType::City;
    rioCity.name = "Rio de Janeiro";
    rioCity.parent = "Rio de Janeiro";
    rioCity.country = "Brazil";
    rioCity.point = GeoPoint{-43.2,-22.9};
    catalog.add(std::move(rioCity));

    Feature spState;
    spState.id = "ne:state:sp";
    spState.type = LocationType::State;
    spState.name = "São Paulo";
    spState.parent = "Brazil";
    spState.country = "Brazil";
    spState.polygons = {rectangle(-54,-26,-44,-20)};
    catalog.add(std::move(spState));

    Feature spCity;
    spCity.id = "ne:city:sp";
    spCity.type = LocationType::City;
    spCity.name = "São Paulo";
    spCity.parent = "São Paulo";
    spCity.country = "Brazil";
    spCity.point = GeoPoint{-46.6333,-23.5505};
    catalog.add(std::move(spCity));

    Feature amapa;
    amapa.id = "ne:state:ap";
    amapa.type = LocationType::State;
    amapa.name = "Amapá";
    amapa.parent = "Brazil";
    amapa.country = "Brazil";
    amapa.polygons = {rectangle(-53,0,-50,4)};
    catalog.add(std::move(amapa));

    Feature brasilia;
    brasilia.id = "ne:city:bsb";
    brasilia.type = LocationType::City;
    brasilia.name = "Brasília";
    brasilia.parent = "Distrito Federal";
    brasilia.country = "Brazil";
    brasilia.point = GeoPoint{-47.8825,-15.7942};
    catalog.add(std::move(brasilia));

    return catalog;
}

void testSearchIdentity() {
    auto catalog = populatedCatalog();
    auto rio = catalog.search("Rio de Janeiro");
    check(rio.size() == 2, "Rio City and State must remain distinct");
    check(rio[0]->id != rio[1]->id, "results must not alias one ID");
    check(catalog.search("rio de janeiro", LocationType::State).size() == 1,
          "typed State must disambiguate Rio");
    check(catalog.search("rio de janeiro", LocationType::City).size() == 1,
          "typed City must disambiguate Rio");
    auto saopaulo = catalog.search("SAO PAULO");
    check(saopaulo.size() == 2, "accent folding must match State and City");
    check(catalog.search("amapa", LocationType::State).size() == 1,
          "Amapa must match Amapá without accent");
    check(catalog.search("Brasilia", LocationType::City).size() == 1,
          "Brasilia must match Brasília without accent");
    check(catalog.search("brasil", LocationType::Country).size() == 1,
          "country alias Brasil must match Brazil");
    check(catalog.search("").empty(), "empty query must not dump entire catalog");
    check(catalog.find("missing") == nullptr, "no invented fallback IDs");
}

void testIndependentRegionStyle() {
    auto catalog = populatedCatalog();
    MapScene scene;
    check(static_cast<bool>(scene.addRegion(catalog, "rj_obj", "ne:state:rj")),
          "add state polygon");
    check(static_cast<bool>(scene.addRegion(catalog, "br_obj", "ne:country:br")),
          "add country polygon");
    check(!scene.addRegion(catalog, "rio_city_region", "ne:city:rio"),
          "city point must not be invented as polygon");
    Style stateStyle;
    stateStyle.fill = {0.1,0.2,0.9,1.0};
    check(static_cast<bool>(scene.setRegionStyle("rj_obj", stateStyle)), "style RJ");
    check(scene.regions()[0].style.fill.blue == 0.9, "RJ fill changed");
    check(scene.regions()[1].style.fill.blue != 0.9, "Brazil not changed");
    Style outOfRange;
    outOfRange.opacity = 1.25;
    check(scene.setRegionStyle("rj_obj", outOfRange).error == SceneError::InvalidValue,
          "reject invalid opacity without corrupting existing style");
    check(scene.regions()[0].style.fill.blue == 0.9, "reject must preserve state");
    check(scene.addRegion(catalog, "rj_obj", "ne:state:rj").error == SceneError::DuplicateObject,
          "object ID collisions forbidden");
}

void testCameraAndAnchors() {
    auto catalog = populatedCatalog();
    MapScene scene;
    const auto oldPose = scene.camera();
    check(static_cast<bool>(scene.focusCamera(catalog,"ne:city:sp")),
          "focus São Paulo City");
    check(std::abs(scene.camera().center.longitude - (-46.6333)) < 1e-6,
          "camera points to city, not state centroid");
    check(scene.focusCamera(catalog,"ne:state:sp").error == SceneError::WrongGeometryType,
          "region focus must not silently choose a representative point");
    check(scene.camera().center.longitude != oldPose.center.longitude,
          "camera updated");
    const auto a = viewPosition({-43.2,-22.9},scene.camera(),1920,1080);
    const auto b = viewPosition({-47.8825,-15.7942},scene.camera(),1920,1080);
    check(std::isfinite(a.x)&&std::isfinite(b.x), "projected anchors finite");
    auto zoomed = scene.camera();
    zoomed.scale = 1.5;
    check(static_cast<bool>(scene.setCamera(zoomed)), "shared zoom change");
    const auto a2 = viewPosition({-43.2,-22.9},scene.camera(),1920,1080);
    const auto b2 = viewPosition({-47.8825,-15.7942},scene.camera(),1920,1080);
    check(std::abs((a2.x - b2.x) - 1.5*(a.x-b.x)) < 1e-6,
          "both objects move in exactly the same shared projection");
    check(std::abs((a2.y - b2.y) - 1.5*(a.y-b.y)) < 1e-6,
          "vertical shared zoom is uniform");
    const auto datelineA = viewPosition({179.5,0},{{-179.5,0},1},1920,1080);
    check(std::abs(datelineA.x-960) < 20, "antimeridian shortest wrap");
    check(scene.setCamera({{-46.6,-23.5},0}).error == SceneError::InvalidValue,
          "invalid camera zoom rejected");
}

void testExplicitStateEndpointRoute() {
    auto catalog = populatedCatalog();
    MapScene scene;
    check(scene.addRoute(catalog,"route1","ne:city:bsb","ne:state:ap",std::nullopt).error ==
          SceneError::MissingExplicitEndpoint,"a State is not a single point");
    check(scene.routes().empty(), "no silent Macapá/centroid route");
    check(scene.addRoute(catalog,"route1","ne:city:bsb","ne:state:ap",
                         GeoPoint{-46.6,-23.5}).error == SceneError::EndpointOutsideRegion,
          "reject endpoint outside Amapá");
    check(scene.routes().empty(), "reject must not create orphan Route");
    check(static_cast<bool>(scene.addRoute(catalog,"route1","ne:city:bsb",
                                          "ne:state:ap",GeoPoint{-51.6,1.3})),
          "accept editor-chosen endpoint in Amapá");
    check(std::abs(scene.routes().front().to.latitude-1.3)<1e-8,
          "store exact explicit endpoint, not default capital");
    check(scene.addRoute(catalog,"route1","ne:city:bsb","ne:state:ap",
                         GeoPoint{-51.6,1.3}).error == SceneError::DuplicateObject,
          "route object ID unique");
    Style routeStyle;
    routeStyle.stroke = {0.3,0.4,1.0,1.0};
    check(static_cast<bool>(scene.setRouteStyle("route1",routeStyle)),
          "route style update");
    check(scene.routes()[0].style.stroke.blue == 1.0, "route style stored");
}

void testTopology() {
    Polygon withHole{{
        {{-4,-4},{4,-4},{4,4},{-4,4},{-4,-4}},
        {{-1,-1},{1,-1},{1,1},{-1,1},{-1,-1}}
    }};
    check(contains(withHole,{2,2}), "inside outer polygon");
    check(!contains(withHole,{0,0}), "hole must not be filled");
    check(!contains(withHole,{10,10}), "outside polygon");
    check(contains(withHole,{4,0}), "boundary allowed as selected endpoint");
}

void testCatalogFileFormat() {
    std::stringstream in;
    in << "CARTORIG_ATOMIC_GEO_V1\n";
    in << "ne:test:1\tstate\tRio de Janeiro\tBrazil\tBrazil\tRio de Janeiro State\t.\t.\t";
    in << "-45,-24;-40,-24;-40,-20;-45,-20;-45,-24\n";
    in << "ne:test:2\tcity\tRio de Janeiro\tRio de Janeiro\tBrazil\t\t-43.2\t-22.9\t\n";
    auto catalog = Catalog::load(in);
    check(catalog.size()==2,"parse two catalog features");
    check(contains(*catalog.find("ne:test:1"),{-43,-22}),"parse real polygon");
    check(catalog.search("rio de janeiro").size()==2,"typed ambiguity preserved on disk");
    std::stringstream bad("WRONG_VERSION\n");
    bool rejected=false;
    try { auto unused = Catalog::load(bad); (void)unused; }
    catch(const std::invalid_argument&) {rejected=true;}
    check(rejected, "unknown versions rejected");
}

} // namespace

int main() {
    try {
        testSearchIdentity();
        testIndependentRegionStyle();
        testCameraAndAnchors();
        testExplicitStateEndpointRoute();
        testTopology();
        testCatalogFileFormat();
        std::cout<<"PASS: "<<checks<<" cartographic assertions (offline C++ core)\n";
        return 0;
    } catch(const std::exception& e) {
        std::cerr<<"FAIL: "<<e.what()<<" after "<<checks<<" assertions\n";
        return 1;
    }
}
