#include "inspector_session.hpp"

#include <iostream>
#include <stdexcept>
#include <string>

using namespace cartorig;
namespace {
int assertions = 0;
void expect(bool yes,const char* message) {
    ++assertions;
    if (!yes) throw std::runtime_error(message);
}
Polygon rectangle(double w,double s,double e,double n) {
    return {{{{w,s},{e,s},{e,n},{w,n},{w,s}}}};
}
Catalog catalog() {
    Catalog c;
    Feature rj;
    rj.id="rj-state";rj.name="Rio de Janeiro";rj.country="Brazil";
    rj.type=LocationType::State;rj.polygons={rectangle(-45,-24,-40,-20)};
    c.add(rj);
    Feature city;
    city.id="rj-city";city.name="Rio de Janeiro";city.country="Brazil";
    city.type=LocationType::City;city.point=GeoPoint{-43.2,-22.9};
    c.add(city);
    Feature spState;
    spState.id="sp-state";spState.name="São Paulo";spState.country="Brazil";
    spState.type=LocationType::State;spState.polygons={rectangle(-54,-26,-44,-20)};
    c.add(spState);
    Feature spCity;
    spCity.id="sp-city";spCity.name="São Paulo";spCity.country="Brazil";
    spCity.type=LocationType::City;spCity.point=GeoPoint{-46.6,-23.5};
    c.add(spCity);
    Feature ap;
    ap.id="ap-state";ap.name="Amapá";ap.country="Brazil";
    ap.type=LocationType::State;ap.polygons={rectangle(-53,0,-50,4)};
    c.add(ap);
    Feature macapa;
    macapa.id="macapa-city";macapa.name="Macapá";macapa.country="Brazil";
    macapa.parent="Amapá";macapa.type=LocationType::City;
    macapa.point=GeoPoint{-51.05,0.1};
    c.add(macapa);
    Feature bsb;
    bsb.id="bsb-city";bsb.name="Brasília";bsb.country="Brazil";
    bsb.type=LocationType::City;bsb.point=GeoPoint{-47.8825,-15.7942};
    c.add(bsb);
    return c;
}
}
int main() {
    try {
        auto places=catalog();
        InspectorSession session(places);
        expect(session.find("Rio de Janeiro",std::nullopt).size()==2,"ambiguous Rio search exposes both");
        auto states=session.find("rio de janeiro",LocationType::State);
        expect(states.size()==1 && states[0].polygonAvailable,"State has region geometry");
        auto cities=session.find("rio de janeiro",LocationType::City);
        expect(cities.size()==1 && !cities[0].polygonAvailable,"City is not a polygon");
        expect(session.addRegion("Rio de Janeiro",LocationType::City,0).error==
               SceneError::WrongGeometryType,"cannot add city as region");
        expect(static_cast<bool>(session.addRegion("Rio de Janeiro",LocationType::State,0)),
               "add Rio state in one semantic command");
        expect(session.objectCount()==1 && session.selectedIndex()==1,"new region selected");
        Style st;
        st.fill={0.2,0.3,0.9,1.0};
        expect(static_cast<bool>(session.setSelectedStyle(st)),"style selected object");
        expect(session.focusCamera("São Paulo",LocationType::State,0).error==
               SceneError::WrongGeometryType,"State not silently given a city center");
        expect(static_cast<bool>(session.focusCamera("São Paulo",LocationType::City,0)),
               "city camera focuses precise point");
        expect(session.addRoute("Brasília","Amapá",std::nullopt).error==
               SceneError::MissingExplicitEndpoint,
               "region alone cannot imply Macapá or a default coordinate");
        InspectorSession chosenCity(places);
        expect(static_cast<bool>(chosenCity.addRoute(
                "Brasília","Amapá",std::nullopt,"Macapá")),
               "user may explicitly choose Macapá by city name");
        expect(chosenCity.scene().routes()[0].to.latitude==0.1,
               "city endpoint must equal catalog coordinate and be inside Amapá");
        expect(chosenCity.addRoute("Brasília","Amapá",std::nullopt,"São Paulo").error==
               SceneError::MissingFeature,
               "chosen city outside state cannot be silently accepted");
        expect(session.addRoute("Brasília","Amapá",GeoPoint{-46.6,-23.5}).error==
               SceneError::EndpointOutsideRegion,"state endpoint must be chosen inside it");
        expect(static_cast<bool>(session.addRoute("Brasília","Amapá",GeoPoint{-51.6,1.3})),
               "Brasília→Amapá route with explicit endpoint");
        expect(session.objectCount()==2 && session.selectedIndex()==2,"route is selected");
        expect(session.objectsSummary().find("Brasília")!=std::string::npos,
               "route visible in objects summary");
        expect(static_cast<bool>(session.selectObject(1)),"reselect RJ");
        expect(session.selectedStyle()->fill.blue==0.9,"RJ color persists after route addition");
        const auto snapshot=session.save();
        InspectorSession reopened(places);
        reopened.restore(snapshot);
        expect(reopened.objectCount()==2,"project snapshot restores objects");
        expect(reopened.scene().regions()[0].style.fill.blue==0.9,"project restores independent color");
        expect(reopened.scene().routes()[0].to.latitude==1.3,"project restores editor-chosen route endpoint");
        bool rejected=false;
        try { reopened.restore("corrupt project"); }
        catch(const std::invalid_argument&) {rejected=true;}
        expect(rejected && reopened.objectCount()==2,"invalid project restore preserves existing scene");
        expect(!reopened.selectObject(999),"selection index is never silently clipped");
        std::cout<<"PASS: "<<assertions<<" native-Inspector semantic session assertions\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr<<"FAIL: "<<error.what()<<" at check "<<assertions<<"\n";
        return 1;
    }
}
