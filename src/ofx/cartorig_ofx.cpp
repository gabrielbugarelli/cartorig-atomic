// CartoRig Atomic — native OFX host adapter, written from scratch.
// SPDX note: source license selection remains pending owner approval.
// OpenFX headers are the independently licensed ASWF SDK, not bundled.
#include "cartorig_core.hpp"
#include "cartorig_renderer.hpp"
#include "inspector_session.hpp"

#include "ofxCore.h"
#include "ofxImageEffect.h"
#include "ofxParam.h"
#include "ofxProperty.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <memory>
#include <mutex>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#if defined(_WIN32)
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#else
#include <dlfcn.h>
#endif

namespace {
using namespace cartorig;
namespace fs = std::filesystem;

const OfxHost* host = nullptr;
const OfxPropertySuiteV1* property = nullptr;
const OfxImageEffectSuiteV1* image = nullptr;
const OfxParameterSuiteV1* parameters = nullptr;

constexpr const char* kPluginId = "org.cartorig.atomic.Map";
constexpr const char* kScene = "sceneSnapshot";
constexpr const char* kSearch = "locationSearch";
constexpr const char* kType = "locationType";
constexpr const char* kMatch = "locationMatch";
constexpr const char* kSearchResults = "locationResults";
constexpr const char* kAddRegion = "addRegion";
constexpr const char* kFocus = "focusCamera";
constexpr const char* kList = "sceneObjects";
constexpr const char* kSelect = "selectedObject";
constexpr const char* kSelectedInfo = "selectedInfo";
constexpr const char* kFill = "selectedFill";
constexpr const char* kStroke = "selectedStroke";
constexpr const char* kOpacity = "selectedOpacity";
constexpr const char* kWidth = "selectedStrokeWidth";
constexpr const char* kVisible = "selectedVisible";
constexpr const char* kCamera = "cameraCenter";
constexpr const char* kZoom = "cameraZoom";
constexpr const char* kOrigin = "routeOrigin";
constexpr const char* kDestination = "routeState";
constexpr const char* kEndpoint = "routeEndpoint";
constexpr const char* kAddRoute = "addRoute";
constexpr const char* kOcean = "oceanFill";
constexpr const char* kLand = "landFill";
constexpr const char* kStatus = "statusMessage";

struct Instance {
    OfxImageClipHandle output = nullptr;
    std::recursive_mutex mutex;
    bool syncingUi = false;
    std::shared_ptr<const Catalog> catalog;
    std::string dataIssue;
};

bool ok(OfxStatus status) { return status == kOfxStatOK; }

void verify(OfxStatus status, const char* action) {
    if (!ok(status)) throw std::runtime_error(std::string(action) +
                                              " (OFX status " + std::to_string(status) + ")");
}

fs::path libraryPath() {
#if defined(_WIN32)
    HMODULE module = nullptr;
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                            GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            reinterpret_cast<LPCWSTR>(&libraryPath), &module))
        throw std::runtime_error("unable to locate OpenFX module");
    std::wstring value(4096, L'\0');
    DWORD size = GetModuleFileNameW(module, value.data(),
                                    static_cast<DWORD>(value.size()));
    if (size == 0 || size >= value.size())
        throw std::runtime_error("OpenFX module path unavailable");
    value.resize(size);
    return fs::path(value);
#else
    Dl_info info{};
    if (!dladdr(reinterpret_cast<void*>(&libraryPath), &info) || !info.dli_fname)
        throw std::runtime_error("OpenFX module path unavailable");
    return fs::path(info.dli_fname);
#endif
}

fs::path catalogPath() {
    if (const char* directory = std::getenv("CARTORIG_ATOMIC_DATA_DIR")) {
        if (*directory) return fs::path(directory) / "cartorig-natural-earth-10m.catalog";
    }
    return libraryPath().parent_path().parent_path() /
           "Resources" / "cartorig-natural-earth-10m.catalog";
}

std::shared_ptr<const Catalog> getCatalog(std::string& issue) {
    static std::mutex guard;
    static std::shared_ptr<const Catalog> cached;
    static std::string cachedIssue;
    static bool attempted = false;
    std::lock_guard<std::mutex> lock(guard);
    if (!attempted) {
        attempted = true;
        try {
            const auto path = catalogPath();
            std::ifstream file(path, std::ios::binary);
            if (!file) throw std::runtime_error("offline data pack unavailable: " + path.string());
            auto loaded = std::make_shared<Catalog>(Catalog::load(file));
            if (loaded->size() == 0)
                throw std::runtime_error("offline catalog has zero geographic features");
            cached = std::move(loaded);
        } catch (const std::exception& error) {
            cachedIssue = error.what();
            cached = std::make_shared<Catalog>();
        }
    }
    issue = cachedIssue;
    return cached;
}

OfxParamHandle param(OfxImageEffectHandle effect, const char* name) {
    OfxParamSetHandle set = nullptr;
    verify(image->getParamSet(effect, &set), "get effect param set");
    OfxParamHandle result = nullptr;
    verify(parameters->paramGetHandle(set, name, &result, nullptr), name);
    return result;
}

std::string stringValue(OfxImageEffectHandle effect, const char* name) {
    char* value = nullptr;
    verify(parameters->paramGetValue(param(effect, name), &value), "read string parameter");
    return value ? value : "";
}

int intValue(OfxImageEffectHandle effect, const char* name) {
    int result = 0;
    verify(parameters->paramGetValue(param(effect, name), &result), "read integer parameter");
    return result;
}

double doubleValue(OfxImageEffectHandle effect, const char* name) {
    double result = 0;
    verify(parameters->paramGetValue(param(effect, name), &result), "read double parameter");
    return result;
}

std::array<double,2> positionValue(OfxImageEffectHandle effect, const char* name,
                                   double time, bool atTime) {
    std::array<double,2> result{};
    const auto handle = param(effect, name);
    if (atTime)
        verify(parameters->paramGetValueAtTime(handle, time, &result[0], &result[1]),
               "read animated position");
    else
        verify(parameters->paramGetValue(handle, &result[0], &result[1]),
               "read position");
    return result;
}

double scalarAtTime(OfxImageEffectHandle effect, const char* name, double time) {
    double value = 0;
    verify(parameters->paramGetValueAtTime(param(effect,name),time,&value),
           "read animated scalar");
    return value;
}

Color colorValue(OfxImageEffectHandle effect, const char* name) {
    Color c;
    verify(parameters->paramGetValue(param(effect,name),
           &c.red,&c.green,&c.blue,&c.alpha),"read RGBA color");
    return c;
}

void setString(OfxImageEffectHandle effect, const char* name, const std::string& value) {
    verify(parameters->paramSetValue(param(effect,name),value.c_str()),"write Inspector text");
}

void setInformationalText(OfxImageEffectHandle effect, const char* name,
                          const std::string& value) {
    // A few OFX hosts reject paramSetValue on disabled/read-only controls.
    // This is optional visual feedback, not the canonical scene store.
    try { setString(effect,name,value); } catch (...) {}
}

void setInt(OfxImageEffectHandle effect, const char* name, int value) {
    verify(parameters->paramSetValue(param(effect,name),value),"write Inspector index");
}

void setDouble(OfxImageEffectHandle effect, const char* name, double value) {
    verify(parameters->paramSetValue(param(effect,name),value),"write Inspector scalar");
}

void setPosition(OfxImageEffectHandle effect, const char* name, GeoPoint value) {
    verify(parameters->paramSetValue(param(effect,name),
                                    value.longitude,value.latitude),"write Inspector position");
}

void setColor(OfxImageEffectHandle effect, const char* name, Color c) {
    verify(parameters->paramSetValue(param(effect,name),
                c.red,c.green,c.blue,c.alpha),"write Inspector color");
}

void setStatus(OfxImageEffectHandle effect, const std::string& message) {
    // Some hosts do not permit programmatic changes to a disabled
    // label parameter: a failed notification must not corrupt scene state.
    try { setString(effect,kStatus,message); } catch (...) {}
}

Instance* instanceData(OfxImageEffectHandle effect) {
    OfxPropertySetHandle props=nullptr;
    verify(image->getPropertySet(effect,&props),"get instance props");
    void* pointer=nullptr;
    verify(property->propGetPointer(props,kOfxPropInstanceData,0,&pointer),
           "get plugin instance data");
    return static_cast<Instance*>(pointer);
}

std::optional<LocationType> selectedType(OfxImageEffectHandle effect) {
    switch (intValue(effect,kType)) {
        case 1: return LocationType::Country;
        case 2: return LocationType::State;
        case 3: return LocationType::City;
        default: return std::nullopt;
    }
}

std::string searchDescription(const InspectorSession& session,
                              const std::string& query,
                              std::optional<LocationType> type) {
    if (query.empty()) return "Type a place name. Select a result number, then Add or Focus.";
    const auto entries = session.find(query,type);
    if (entries.empty()) return "No matching locations in installed offline data.";
    std::ostringstream out;
    std::size_t count=0;
    for (const auto& e:entries) {
        const char* label = e.type == LocationType::City ? "City" :
                            e.type == LocationType::State ? "State" : "Country";
        out << ++count << ". " << e.name << " [" << label << "]";
        if(!e.parent.empty()) out << ", " << e.parent;
        if(!e.country.empty() && e.parent != e.country) out << ", " << e.country;
        if(e.polygonAvailable) out << " (region)";
        out << '\n';
    }
    return out.str();
}

std::string errorText(SceneError e) {
    switch (e) {
        case SceneError::None: return "OK";
        case SceneError::MissingFeature: return "Select a valid, unambiguous geographic match.";
        case SceneError::WrongGeometryType: return "This location is a point, not a region polygon.";
        case SceneError::MissingExplicitEndpoint: return "Choose an explicit point within the destination state.";
        case SceneError::EndpointOutsideRegion: return "The destination point is outside the selected state.";
        case SceneError::DuplicateObject: return "Object already exists; choose a different identity.";
        case SceneError::InvalidValue: return "Invalid numeric/style input.";
    }
    return "Unknown scene validation error";
}

void refreshResults(OfxImageEffectHandle effect,InspectorSession& session) {
    setInformationalText(effect,kSearchResults,searchDescription(
        session,stringValue(effect,kSearch),selectedType(effect)));
}

void refreshSelection(OfxImageEffectHandle effect,InspectorSession& session) {
    setInformationalText(effect,kList,session.objectsSummary());
    setInformationalText(effect,kSelectedInfo,session.selectedDescription());
    if (auto style=session.selectedStyle()) {
        setColor(effect,kFill,style->fill);
        setColor(effect,kStroke,style->stroke);
        setDouble(effect,kOpacity,style->opacity);
        setDouble(effect,kWidth,style->strokeWidthPixels);
        setInt(effect,kVisible,style->visible ? 1 : 0);
    }
}

void refreshFromProject(OfxImageEffectHandle effect,Instance& state) {
    InspectorSession session(*state.catalog);
    session.restore(stringValue(effect,kScene));
    const int index=intValue(effect,kSelect);
    (void)session.selectObject(index>0?static_cast<std::size_t>(index):0);
    const bool previous=state.syncingUi;
    state.syncingUi=true;
    try {
        refreshResults(effect,session);
        refreshSelection(effect,session);
    } catch (...) {
        state.syncingUi=previous;
        throw;
    }
    state.syncingUi=previous;
}

void commitSession(OfxImageEffectHandle effect,Instance& state,
                   InspectorSession& session,const std::string& status) {
    // Host stores this parameter inside the clip/project; no hidden global
    // cache may become the canonical source of geographic object state.
    const bool previous=state.syncingUi;
    state.syncingUi=true;
    try {
        setString(effect,kScene,session.save());
        setInt(effect,kSelect,static_cast<int>(session.selectedIndex()));
        refreshSelection(effect,session);
        setStatus(effect,status);
    } catch (...) {
        state.syncingUi=previous;
        throw;
    }
    state.syncingUi=previous;
}

OfxStatus onInstanceChanged(OfxImageEffectHandle effect,OfxPropertySetHandle args) {
    Instance* state=instanceData(effect);
    if(!state) return kOfxStatFailed;
    char* name=nullptr;
    if(!ok(property->propGetString(args,kOfxPropName,0,&name))||!name)
        return kOfxStatReplyDefault;

    const std::string key=name;
    // A host may reissue instance-change callbacks while restoring a saved
    // project. Destructive buttons must only respond to an actual user edit.
    char* reason=nullptr;
    const bool userEdit=ok(property->propGetString(
        args,kOfxPropChangeReason,0,&reason)) &&
        reason && std::strcmp(reason,kOfxChangeUserEdited)==0;
    if ((key==kAddRegion || key==kFocus || key==kAddRoute) && !userEdit)
        return kOfxStatOK;
    if (key==kScene || key==kStatus || key==kSearchResults ||
        key==kList || key==kSelectedInfo) return kOfxStatOK;

    std::lock_guard<std::recursive_mutex> lock(state->mutex);
    if (state->syncingUi) return kOfxStatOK;

    if (!state->dataIssue.empty()) {
        setStatus(effect,state->dataIssue);
        return kOfxStatOK;
    }
    InspectorSession session(*state->catalog);
    session.restore(stringValue(effect,kScene));
    const int selection=intValue(effect,kSelect);
    (void)session.selectObject(selection>0?static_cast<std::size_t>(selection):0);

    if(key==kSearch || key==kType || key==kMatch) {
        const bool was=state->syncingUi;state->syncingUi=true;
        try { refreshResults(effect,session); }
        catch (...) {state->syncingUi=was;throw;}
        state->syncingUi=was;
        return kOfxStatOK;
    }
    if(key==kSelect) {
        const auto result=session.selectObject(selection>0?static_cast<std::size_t>(selection):0);
        if(!result) {setStatus(effect,errorText(result.error));return kOfxStatOK;}
        commitSession(effect,*state,session,session.selectedDescription());
        return kOfxStatOK;
    }
    if(key==kAddRegion || key==kFocus) {
        const int index=intValue(effect,kMatch);
        const auto type=selectedType(effect);
        const auto query=stringValue(effect,kSearch);
        const auto result=index<=0 ? SceneResult{SceneError::MissingFeature,""} :
            (key==kAddRegion ?
                session.addRegion(query,type,static_cast<std::size_t>(index-1)) :
                session.focusCamera(query,type,static_cast<std::size_t>(index-1)));
        if(!result) {setStatus(effect,errorText(result.error));return kOfxStatOK;}
        if(key==kFocus) {
            const bool was=state->syncingUi;state->syncingUi=true;
            try {setPosition(effect,kCamera,session.scene().camera().center);}
            catch (...) {state->syncingUi=was;throw;}
            state->syncingUi=was;
        }
        commitSession(effect,*state,session,key==kAddRegion ?
                      "Region added to Map Scene." : "Camera focused on selected city.");
        return kOfxStatOK;
    }
    if(key==kAddRoute) {
        const auto p=positionValue(effect,kEndpoint,0.0,false);
        const auto result=session.addRoute(
            stringValue(effect,kOrigin),
            stringValue(effect,kDestination), {p[0],p[1]});
        if(!result){setStatus(effect,errorText(result.error));return kOfxStatOK;}
        commitSession(effect,*state,session,"Route added with explicit destination.");
        return kOfxStatOK;
    }
    if(key==kFill || key==kStroke || key==kOpacity ||
       key==kWidth || key==kVisible) {
        auto maybe=session.selectedStyle();
        if(!maybe){setStatus(effect,"Select an authored object first.");return kOfxStatOK;}
        Style st=*maybe;
        st.fill=colorValue(effect,kFill);
        st.stroke=colorValue(effect,kStroke);
        st.opacity=doubleValue(effect,kOpacity);
        st.strokeWidthPixels=doubleValue(effect,kWidth);
        st.visible=intValue(effect,kVisible)!=0;
        const auto result=session.setSelectedStyle(st);
        if(!result){setStatus(effect,errorText(result.error));return kOfxStatOK;}
        commitSession(effect,*state,session,"Selected object style updated.");
        return kOfxStatOK;
    }
    if(key==kCamera || key==kZoom || key==kOcean || key==kLand)
        return kOfxStatOK; // render reads animated/updated host params.
    return kOfxStatReplyDefault;
}

void setLabel(OfxPropertySetHandle props,const char* label,const char* help=nullptr) {
    verify(property->propSetString(props,kOfxPropLabel,0,label),"set label");
    if(help) property->propSetString(props,kOfxParamPropHint,0,help);
}

OfxPropertySetHandle defineParam(OfxParamSetHandle set,const char* type,
                                 const char* name,const char* label,
                                 bool animates=false) {
    OfxPropertySetHandle props=nullptr;
    verify(parameters->paramDefine(set,type,name,&props),"define Inspector parameter");
    setLabel(props,label);
    property->propSetInt(props,kOfxParamPropAnimates,0,animates?1:0);
    return props;
}

void defaultDouble(OfxPropertySetHandle p,double value,double low,double high) {
    property->propSetDouble(p,kOfxParamPropDefault,0,value);
    property->propSetDouble(p,kOfxParamPropMin,0,low);
    property->propSetDouble(p,kOfxParamPropMax,0,high);
    property->propSetDouble(p,kOfxParamPropDisplayMin,0,low);
    property->propSetDouble(p,kOfxParamPropDisplayMax,0,high);
}

void defineColor(OfxParamSetHandle set,const char* name,const char* label,
                 Color initial,bool animates=false) {
    auto p=defineParam(set,kOfxParamTypeRGBA,name,label,animates);
    const double values[] = {initial.red,initial.green,initial.blue,initial.alpha};
    for(int i=0;i<4;++i) property->propSetDouble(p,kOfxParamPropDefault,i,values[i]);
}

OfxPropertySetHandle defineText(OfxParamSetHandle set,const char* name,const char* label,
                const char* initial,bool editable=true,bool multiLine=false) {
    auto p=defineParam(set,kOfxParamTypeString,name,label);
    property->propSetString(p,kOfxParamPropDefault,0,initial);
    property->propSetString(p,kOfxParamPropStringMode,0,
                           multiLine?kOfxParamStringIsMultiLine:kOfxParamStringIsSingleLine);
    if(!editable) property->propSetInt(p,kOfxParamPropEnabled,0,0);
    return p;
}

void definePage(OfxParamSetHandle set,const char* name,
                std::initializer_list<const char*> children) {
    auto p=defineParam(set,kOfxParamTypePage,name,name);
    int i=0;
    for(const char* child:children)
        property->propSetString(p,kOfxParamPropPageChild,i++,child);
}

OfxStatus describe(OfxImageEffectHandle effect) {
    OfxPropertySetHandle props=nullptr;
    verify(image->getPropertySet(effect,&props),"describe plugin");
    verify(property->propSetString(props,kOfxPropLabel,0,"CartoRig Atomic Map"),"plugin label");
    property->propSetString(props,kOfxImageEffectPluginPropGrouping,0,"CartoRig Atomic");
    property->propSetString(props,kOfxImageEffectPropSupportedContexts,0,
                            kOfxImageEffectContextGenerator);
    property->propSetString(props,kOfxImageEffectPropSupportedContexts,1,
                            kOfxImageEffectContextFilter);
    property->propSetString(props,kOfxImageEffectPropSupportedPixelDepths,0,kOfxBitDepthByte);
    property->propSetString(props,kOfxImageEffectPropSupportedPixelDepths,1,kOfxBitDepthFloat);
    property->propSetString(props,kOfxImageEffectPluginRenderThreadSafety,0,
                            kOfxImageEffectRenderFullySafe);
    property->propSetInt(props,kOfxImageEffectPropSupportsTiles,0,0);
    return kOfxStatOK;
}

OfxStatus describeContext(OfxImageEffectHandle effect,OfxPropertySetHandle args) {
    char* context=nullptr;
    verify(property->propGetString(args,kOfxImageEffectPropContext,0,&context),
           "read OFX context");
    OfxPropertySetHandle clip=nullptr;
    verify(image->clipDefine(effect,kOfxImageEffectOutputClipName,&clip),"output clip");
    property->propSetString(clip,kOfxImageEffectPropSupportedComponents,0,
                            kOfxImageComponentRGBA);
    if(context && std::strcmp(context,kOfxImageEffectContextFilter)==0) {
        verify(image->clipDefine(effect,kOfxImageEffectSimpleSourceClipName,&clip),
               "source clip");
        property->propSetString(clip,kOfxImageEffectPropSupportedComponents,0,
                                kOfxImageComponentRGBA);
        // Full-map renderer replaces the entire source image for the
        // filter fallback. No implicit source or alpha assumptions.
    }
    OfxParamSetHandle set=nullptr;
    verify(image->getParamSet(effect,&set),"define Inspector param set");
    defineText(set,kSearch,"Find Location","",true);
    {
        auto p=defineParam(set,kOfxParamTypeChoice,kType,"Location Type");
        const char* options[]={"All","Country","State","City"};
        for(int i=0;i<4;++i)property->propSetString(p,kOfxParamPropChoiceOption,i,options[i]);
        property->propSetInt(p,kOfxParamPropDefault,0,0);
    }
    {
        auto p=defineParam(set,kOfxParamTypeInteger,kMatch,"Result Number");
        property->propSetInt(p,kOfxParamPropDefault,0,1);
        property->propSetInt(p,kOfxParamPropMin,0,1);
        property->propSetInt(p,kOfxParamPropMax,0,20);
    }
    defineText(set,kSearchResults,"Matching Places","Type a location name.",false,true);
    defineParam(set,kOfxParamTypePushButton,kAddRegion,"Add Region");
    defineParam(set,kOfxParamTypePushButton,kFocus,"Focus Camera");
    defineText(set,kList,"Map Objects","No objects",false,true);
    {
        auto p=defineParam(set,kOfxParamTypeInteger,kSelect,"Selected Object Number");
        property->propSetInt(p,kOfxParamPropDefault,0,0);
        property->propSetInt(p,kOfxParamPropMin,0,0);
        property->propSetInt(p,kOfxParamPropMax,0,100000);
    }
    defineText(set,kSelectedInfo,"Object","Select an object",false);
    defineColor(set,kFill,"Fill",{0.85,0.45,0.20,1});
    defineColor(set,kStroke,"Stroke",{0.15,0.20,0.24,1});
    {
        auto p=defineParam(set,kOfxParamTypeDouble,kOpacity,"Opacity");
        defaultDouble(p,1.0,0.0,1.0);
    }
    {
        auto p=defineParam(set,kOfxParamTypeDouble,kWidth,"Stroke Width (px)");
        defaultDouble(p,2.0,0.0,100.0);
    }
    {
        auto p=defineParam(set,kOfxParamTypeBoolean,kVisible,"Visible");
        property->propSetInt(p,kOfxParamPropDefault,0,1);
    }
    {
        auto p=defineParam(set,kOfxParamTypeDouble2D,kCamera,
                           "Camera Center (Longitude / Latitude)",true);
        property->propSetDouble(p,kOfxParamPropDefault,0,-53.0);
        property->propSetDouble(p,kOfxParamPropDefault,1,-12.0);
    }
    {
        auto p=defineParam(set,kOfxParamTypeDouble,kZoom,"Camera Zoom",true);
        defaultDouble(p,4.0,0.25,4096.0);
    }
    defineColor(set,kOcean,"Ocean Fill",{0.055,0.115,0.165,1});
    defineColor(set,kLand,"Land Fill",{0.35,0.44,0.39,1});
    defineText(set,kOrigin,"Route From City","Brasília");
    defineText(set,kDestination,"Route To State","Amapá");
    {
        auto p=defineParam(set,kOfxParamTypeDouble2D,kEndpoint,
                           "Explicit Endpoint (Longitude / Latitude)");
        property->propSetDouble(p,kOfxParamPropDefault,0,-51.6);
        property->propSetDouble(p,kOfxParamPropDefault,1,1.3);
    }
    defineParam(set,kOfxParamTypePushButton,kAddRoute,"Add Route");
    defineText(set,kStatus,"Status","Ready — loading offline data",false,true);
    {
        auto p=defineText(set,kScene,"Internal Scene Snapshot","",true,true);
        property->propSetInt(p,kOfxParamPropSecret,0,1);
    }
    definePage(set,"Find",{kSearch,kType,kMatch,kSearchResults,kAddRegion,kFocus});
    definePage(set,"Objects",{kList,kSelect,kSelectedInfo,kFill,kStroke,kOpacity,kWidth,kVisible});
    definePage(set,"Camera",{kCamera,kZoom,kOcean,kLand});
    definePage(set,"Route",{kOrigin,kDestination,kEndpoint,kAddRoute});
    definePage(set,"Info",{kStatus});

    return kOfxStatOK;
}

OfxStatus createInstance(OfxImageEffectHandle effect) {
    auto state=std::make_unique<Instance>();
    state->catalog=getCatalog(state->dataIssue);
    verify(image->clipGetHandle(effect,kOfxImageEffectOutputClipName,
                                &state->output,nullptr),"instance output clip");
    OfxPropertySetHandle props=nullptr;
    verify(image->getPropertySet(effect,&props),"create effect instance");
    verify(property->propSetPointer(props,kOfxPropInstanceData,0,state.get()),
           "attach instance data");
    Instance* owned=state.release();
    try {
        std::lock_guard<std::recursive_mutex> guard(owned->mutex);
        if(!owned->dataIssue.empty())setStatus(effect,owned->dataIssue);
        else refreshFromProject(effect,*owned);
    } catch (...) {
        // Host may reject UI updates during instance creation; if the
        // output clip is valid, allow user interaction to initialize it.
    }
    return kOfxStatOK;
}

OfxStatus destroyInstance(OfxImageEffectHandle effect) {
    Instance* state=instanceData(effect);
    if(state) {
        OfxPropertySetHandle props=nullptr;
        if(ok(image->getPropertySet(effect,&props)))
            property->propSetPointer(props,kOfxPropInstanceData,0,nullptr);
        delete state;
    }
    return kOfxStatOK;
}

OfxStatus regionOfDefinition(OfxImageEffectHandle effect,OfxPropertySetHandle outArgs) {
    OfxPropertySetHandle props=nullptr;
    verify(image->getPropertySet(effect,&props),"get project format");
    double dimensions[2]={1920,1080};
    if(!ok(property->propGetDoubleN(props,kOfxImageEffectPropProjectSize,2,dimensions))) {
        dimensions[0]=1920;dimensions[1]=1080;
    }
    const double rod[4]={0,0,dimensions[0],dimensions[1]};
    verify(property->propSetDoubleN(outArgs,kOfxImageEffectPropRegionOfDefinition,4,rod),
           "set full map RoD");
    return kOfxStatOK;
}

struct OutputImage {
    OfxPropertySetHandle handle=nullptr;
    OfxImageClipHandle clip=nullptr;
    ~OutputImage() {
        if(handle && clip && image) image->clipReleaseImage(handle);
    }
};

OfxStatus render(OfxImageEffectHandle effect,OfxPropertySetHandle args) {
    Instance* state=instanceData(effect);
    if(!state)return kOfxStatFailed;
    double time=0;
    property->propGetDouble(args,kOfxPropTime,0,&time);
    OutputImage output;
    output.clip=state->output;
    verify(image->clipGetImage(output.clip,time,nullptr,&output.handle),"fetch output pixels");
    if(!output.handle)return kOfxStatFailed;
    int bounds[4]={};
    verify(property->propGetIntN(output.handle,kOfxImagePropBounds,4,bounds),
           "fetch pixel bounds");
    int rowBytes=0;
    void* pixels=nullptr;
    char* pixelDepth=nullptr;
    char* components=nullptr;
    verify(property->propGetInt(output.handle,kOfxImagePropRowBytes,0,&rowBytes),
           "fetch row stride");
    verify(property->propGetPointer(output.handle,kOfxImagePropData,0,&pixels),
           "fetch output memory");
    verify(property->propGetString(output.handle,kOfxImageEffectPropPixelDepth,0,
                                   &pixelDepth),"pixel depth");
    verify(property->propGetString(output.handle,kOfxImageEffectPropComponents,0,
                                   &components),"image components");
    if(!pixels || !components ||
       std::strcmp(components,kOfxImageComponentRGBA)!=0)
        return kOfxStatErrImageFormat;
    const bool floating=pixelDepth && std::strcmp(pixelDepth,kOfxBitDepthFloat)==0;
    const bool byteDepth=pixelDepth && std::strcmp(pixelDepth,kOfxBitDepthByte)==0;
    if(!floating && !byteDepth)return kOfxStatErrImageFormat;
    const int imageWidth=bounds[2]-bounds[0];
    const int imageHeight=bounds[3]-bounds[1];
    if(imageWidth<=0 || imageHeight<=0)return kOfxStatErrFormat;
    if(rowBytes==0)return kOfxStatErrFormat;

    if(!state->dataIssue.empty()) {
        // No data means no fabricated map. The error is exposed in the
        // native Inspector; return blank pixels rather than crash.
        for(int y=0;y<imageHeight;++y) {
            auto* row=static_cast<unsigned char*>(pixels)+static_cast<std::ptrdiff_t>(y)*rowBytes;
            std::memset(row,0,static_cast<std::size_t>(imageWidth)*(floating?16:4));
        }
        return kOfxStatOK;
    }

    const auto snapshot=stringValue(effect,kScene);
    InspectorSession session(*state->catalog);
    session.restore(snapshot);
    MapScene scene=session.scene();
    const auto cameraParam=positionValue(effect,kCamera,time,true);
    const double zoom=scalarAtTime(effect,kZoom,time);
    if(!scene.setCamera({{cameraParam[0],cameraParam[1]},zoom}))
        return kOfxStatFailed;

    RenderOptions style;
    style.water=colorValue(effect,kOcean);
    style.land.fill=colorValue(effect,kLand);
    style.land.strokeWidthPixels=0.5;

    // Tile rendering is disabled on the descriptor. If the host sends a
    // sub-image regardless, align the geographic world to project pixels.
    OfxPropertySetHandle effectProps=nullptr;
    verify(image->getPropertySet(effect,&effectProps),"render project dimensions");
    double fullSize[2]={static_cast<double>(imageWidth),static_cast<double>(imageHeight)};
    double scale[2]={1,1};
    property->propGetDoubleN(effectProps,kOfxImageEffectPropProjectSize,2,fullSize);
    property->propGetDoubleN(args,kOfxImageEffectPropRenderScale,2,scale);
    const int fullWidth=std::max(imageWidth,static_cast<int>(std::lround(fullSize[0]*scale[0])));
    const int fullHeight=std::max(imageHeight,static_cast<int>(std::lround(fullSize[1]*scale[1])));
    const Raster frame=renderMap(*state->catalog,scene,fullWidth,fullHeight,style);
    int window[4]={bounds[0],bounds[1],bounds[2],bounds[3]};
    property->propGetIntN(args,kOfxImageEffectPropRenderWindow,4,window);
    const int y0=std::max(window[1],bounds[1]);
    const int y1=std::min(window[3],bounds[3]);
    const int x0=std::max(window[0],bounds[0]);
    const int x1=std::min(window[2],bounds[2]);
    for(int y=y0;y<y1;++y) {
        auto* row=static_cast<unsigned char*>(pixels)+static_cast<std::ptrdiff_t>(y-bounds[1])*rowBytes;
        for(int x=x0;x<x1;++x) {
            const int frameY=fullHeight-1-y;
            const auto rgba=(x>=0 && frameY>=0 && x<fullWidth && frameY<fullHeight)
                ? frame.pixel(x,frameY)
                : std::array<std::uint8_t,4>{0,0,0,0};
            const std::size_t col=static_cast<std::size_t>(x-bounds[0]);
            if(floating) {
                auto* target=reinterpret_cast<float*>(row)+4*col;
                for(int i=0;i<4;++i)target[i]=static_cast<float>(rgba[i])/255.0f;
            } else {
                auto* target=row+4*col;
                std::memcpy(target,rgba.data(),4);
            }
        }
    }
    return kOfxStatOK;
}

OfxStatus mainEntry(const char* action,const void* rawHandle,
                    OfxPropertySetHandle inArgs,OfxPropertySetHandle outArgs) {
    if(!action)return kOfxStatErrBadHandle;
    try {
        const auto effect=reinterpret_cast<OfxImageEffectHandle>(const_cast<void*>(rawHandle));
        if(std::strcmp(action,kOfxActionLoad)==0) {
            if(!host)return kOfxStatErrMissingHostFeature;
            property=static_cast<const OfxPropertySuiteV1*>(
                host->fetchSuite(host->host,kOfxPropertySuite,1));
            image=static_cast<const OfxImageEffectSuiteV1*>(
                host->fetchSuite(host->host,kOfxImageEffectSuite,1));
            parameters=static_cast<const OfxParameterSuiteV1*>(
                host->fetchSuite(host->host,kOfxParameterSuite,1));
            return property && image && parameters ? kOfxStatOK : kOfxStatErrMissingHostFeature;
        }
        if(std::strcmp(action,kOfxActionUnload)==0)return kOfxStatOK;
        if(!property || !image || !parameters)return kOfxStatErrMissingHostFeature;
        if(std::strcmp(action,kOfxActionDescribe)==0)return describe(effect);
        if(std::strcmp(action,kOfxImageEffectActionDescribeInContext)==0)
            return describeContext(effect,inArgs);
        if(std::strcmp(action,kOfxActionCreateInstance)==0)return createInstance(effect);
        if(std::strcmp(action,kOfxActionDestroyInstance)==0)return destroyInstance(effect);
        if(std::strcmp(action,kOfxActionInstanceChanged)==0)
            return onInstanceChanged(effect,inArgs);
        if(std::strcmp(action,kOfxImageEffectActionGetRegionOfDefinition)==0)
            return regionOfDefinition(effect,outArgs);
        if(std::strcmp(action,kOfxImageEffectActionRender)==0)return render(effect,inArgs);
        return kOfxStatReplyDefault;
    } catch(const std::bad_alloc&) {
        return kOfxStatErrMemory;
    } catch(...) {
        // Never throw across the OpenFX C ABI into Resolve.
        return kOfxStatFailed;
    }
}

void setHost(OfxHost* incoming) {host=incoming;}

OfxPlugin plugin={
    kOfxImageEffectPluginApi,
    kOfxImageEffectPluginApiVersion,
    kPluginId,
    0,1,
    setHost,
    mainEntry
};
} // namespace

extern "C" {
OfxExport int OfxGetNumberOfPlugins(void) {return 1;}
OfxExport OfxPlugin* OfxGetPlugin(int index) {
    return index==0 ? &plugin : nullptr;
}
}
