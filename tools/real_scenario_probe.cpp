#include "cartorig_core.hpp"
#include "cartorig_renderer.hpp"
#include "inspector_session.hpp"

#include <cmath>
#include <fstream>
#include <iostream>
#include <stdexcept>

using namespace cartorig;

int main(int argc,char** argv) {
    try {
        if(argc!=2)throw std::invalid_argument("expected official catalog file path");
        std::ifstream input(argv[1],std::ios::binary);
        if(!input)throw std::runtime_error("offline catalog missing");
        auto catalog=Catalog::load(input);
        if(catalog.size()<10000)throw std::runtime_error("incomplete real dataset");
        InspectorSession session(catalog);

        const auto rio=session.find("Rio de Janeiro",LocationType::State);
        const auto sao=session.find("São Paulo",LocationType::City);
        if(rio.empty() || sao.empty())throw std::runtime_error("country/state/city search failed");

        const auto r=session.addRegion("Rio de Janeiro",LocationType::State,0);
        if(!r)throw std::runtime_error("cannot highlight Rio de Janeiro state polygon");
        const auto focus=session.focusCamera("São Paulo",LocationType::City,0);
        if(!focus)throw std::runtime_error("cannot focus São Paulo city");
        auto pose=session.scene().camera();
        pose.scale=5.0;
        const auto route=session.addRoute(
            "Brasília","Amapá",std::nullopt,"Macapá");
        if(!route)throw std::runtime_error(
            "cannot create Brasília → editor-chosen Macapá within Amapá; result="+
            std::to_string(static_cast<int>(route.error)));

        if(session.scene().routes().size()!=1)
            throw std::runtime_error("route identity lost");
        const auto& savedRoute=session.scene().routes().front();
        const auto* state=catalog.find(savedRoute.destinationRegionId);
        if(!state || !contains(*state,savedRoute.to))
            throw std::runtime_error("real Macapá city is outside Amapá polygon");

        const auto encoded=session.save();
        InspectorSession restored(catalog);
        restored.restore(encoded);
        if(restored.scene().regions().size()!=1 || restored.scene().routes().size()!=1)
            throw std::runtime_error("real scene persistence lost objects");

        MapScene view=session.scene();
        if(!view.setCamera(pose))throw std::runtime_error("camera zoom invalid");
        const auto frame=renderMap(catalog,view,640,360);
        if(frame.rgba.size()!=640u*360u*4u)
            throw std::runtime_error("actual geometry did not render RGBA");
        bool nonUniform=false;
        const auto baseline=frame.pixel(0,0);
        for(std::size_t i=4;i+3<frame.rgba.size();i+=4) {
            if(frame.rgba[i]!=baseline[0] ||
               frame.rgba[i+1]!=baseline[1] ||
               frame.rgba[i+2]!=baseline[2]) {
                nonUniform=true;
                break;
            }
        }
        if(!nonUniform)throw std::runtime_error("real Natural Earth frame is empty");
        std::cout<<"PASS: "<<catalog.size()
                 <<" official Natural Earth features; Rio state, São Paulo city, "
                 <<"Brasília → explicitly chosen Macapá inside Amapá; "
                 <<"RGBA rendering; snapshot roundtrip\n";
        return 0;
    }catch(const std::exception& err) {
        std::cerr<<"FAIL: "<<err.what()<<"\n";
        return 1;
    }
}
