// In-process OpenFX host contract test. This is NOT a DaVinci Resolve emulator.
// It exercises actual binary ABI callbacks, one native-Inspector event sequence,
// scene persistence and RGBA output using a small SYNTHETIC catalog fixture.
#include "ofxCore.h"
#include "ofxImageEffect.h"
#include "ofxParam.h"
#include "ofxProperty.h"

#include <algorithm>
#include <array>
#include <cstdarg>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <map>
#include <memory>
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
struct Properties {
    std::map<std::string,std::vector<int>> ints;
    std::map<std::string,std::vector<double>> doubles;
    std::map<std::string,std::vector<std::string>> strings;
    std::map<std::string,std::vector<void*>> pointers;
};
template<class T>
void writeIndexed(std::map<std::string,std::vector<T>>& target,
                  const char* name,int index,T value) {
    if (!name || index<0 || index>5000) throw std::invalid_argument("invalid property");
    auto& slot=target[name];
    if (slot.size()<=static_cast<std::size_t>(index))slot.resize(index+1);
    slot[index]=std::move(value);
}
template<class T>
bool readIndexed(const std::map<std::string,std::vector<T>>& src,
                 const char* name,int index,T& value) {
    if(!name || index<0)return false;
    auto it=src.find(name);
    if(it==src.end() || it->second.size()<=static_cast<std::size_t>(index))return false;
    value=it->second[index];
    return true;
}
Properties* props(OfxPropertySetHandle handle) {
    return reinterpret_cast<Properties*>(handle);
}
OfxPropertySetHandle asProps(Properties* pointer) {
    return reinterpret_cast<OfxPropertySetHandle>(pointer);
}
OfxStatus setString(OfxPropertySetHandle h,const char* key,int index,const char* value) {
    writeIndexed(props(h)->strings,key,index,std::string(value?value:""));
    return kOfxStatOK;
}
OfxStatus setDouble(OfxPropertySetHandle h,const char* key,int index,double value) {
    writeIndexed(props(h)->doubles,key,index,value);return kOfxStatOK;
}
OfxStatus setInt(OfxPropertySetHandle h,const char* key,int index,int value) {
    writeIndexed(props(h)->ints,key,index,value);return kOfxStatOK;
}
OfxStatus setPointer(OfxPropertySetHandle h,const char* key,int index,void* value) {
    writeIndexed(props(h)->pointers,key,index,value);return kOfxStatOK;
}
OfxStatus getString(OfxPropertySetHandle h,const char* key,int index,char** output) {
    std::string value;
    if(!readIndexed(props(h)->strings,key,index,value))return kOfxStatErrUnknown;
    *output=const_cast<char*>(props(h)->strings.at(key)[index].c_str());
    return kOfxStatOK;
}
OfxStatus getDouble(OfxPropertySetHandle h,const char* key,int index,double* out) {
    return readIndexed(props(h)->doubles,key,index,*out)?kOfxStatOK:kOfxStatErrUnknown;
}
OfxStatus getInt(OfxPropertySetHandle h,const char* key,int index,int* out) {
    return readIndexed(props(h)->ints,key,index,*out)?kOfxStatOK:kOfxStatErrUnknown;
}
OfxStatus getPointer(OfxPropertySetHandle h,const char* key,int index,void** out) {
    return readIndexed(props(h)->pointers,key,index,*out)?kOfxStatOK:kOfxStatErrUnknown;
}
OfxStatus getDoubleN(OfxPropertySetHandle h,const char* key,int count,double* out) {
    for(int i=0;i<count;i++)if(getDouble(h,key,i,&out[i])!=kOfxStatOK)return kOfxStatErrUnknown;
    return kOfxStatOK;
}
OfxStatus getIntN(OfxPropertySetHandle h,const char* key,int count,int* out) {
    for(int i=0;i<count;i++)if(getInt(h,key,i,&out[i])!=kOfxStatOK)return kOfxStatErrUnknown;
    return kOfxStatOK;
}
OfxStatus setDoubleN(OfxPropertySetHandle h,const char* key,int count,const double* values) {
    for(int i=0;i<count;++i)setDouble(h,key,i,values[i]);
    return kOfxStatOK;
}
OfxStatus setIntN(OfxPropertySetHandle h,const char* key,int count,const int* values) {
    for(int i=0;i<count;++i)setInt(h,key,i,values[i]);
    return kOfxStatOK;
}

struct Parameter {
    std::string type;
    Properties properties;
    bool hasValue=false;
    std::string text;
    int integer=0;
    std::vector<double> numbers;
};
struct Effect {
    Properties properties;
    Properties outputProps;
    Properties frameProps;
    std::map<std::string,std::unique_ptr<Parameter>> params;
    std::vector<std::uint8_t> frame=std::vector<std::uint8_t>(640u*360u*4u);
};
Parameter* asParameter(OfxParamHandle h) { return reinterpret_cast<Parameter*>(h); }
Effect* asEffect(OfxImageEffectHandle h) { return reinterpret_cast<Effect*>(h); }
Effect* asParamSet(OfxParamSetHandle h) { return reinterpret_cast<Effect*>(h); }
OfxParamSetHandle paramSet(Effect* e) {return reinterpret_cast<OfxParamSetHandle>(e);}
OfxParamHandle paramHandle(Parameter* p) {return reinterpret_cast<OfxParamHandle>(p);}
OfxImageClipHandle clipHandle(Effect* e) {return reinterpret_cast<OfxImageClipHandle>(e);}
OfxImageEffectHandle effectHandle(Effect* e) {return reinterpret_cast<OfxImageEffectHandle>(e);}

OfxStatus defineParam(OfxParamSetHandle h,const char* type,const char* name,
                      OfxPropertySetHandle* out) {
    auto* e=asParamSet(h);
    if(e->params.count(name))return kOfxStatErrExists;
    auto parameter=std::make_unique<Parameter>();
    parameter->type=type;
    auto* saved=parameter.get();
    e->params.emplace(name,std::move(parameter));
    if(out)*out=asProps(&saved->properties);
    return kOfxStatOK;
}
OfxStatus getParam(OfxParamSetHandle h,const char* name,
                   OfxParamHandle* out,OfxPropertySetHandle* propsOut) {
    auto* e=asParamSet(h);
    auto it=e->params.find(name);
    if(it==e->params.end())return kOfxStatErrUnknown;
    if(out)*out=paramHandle(it->second.get());
    if(propsOut)*propsOut=asProps(&it->second->properties);
    return kOfxStatOK;
}
const char* readText(Parameter* p) {
    if(p->hasValue)return p->text.c_str();
    const auto it=p->properties.strings.find(kOfxParamPropDefault);
    if(it!=p->properties.strings.end() && !it->second.empty())return it->second[0].c_str();
    return "";
}
int readInteger(Parameter* p) {
    if(p->hasValue)return p->integer;
    const auto it=p->properties.ints.find(kOfxParamPropDefault);
    return it!=p->properties.ints.end() && !it->second.empty() ? it->second[0] : 0;
}
double readNumber(Parameter* p,std::size_t channel) {
    if(p->hasValue && p->numbers.size()>channel)return p->numbers[channel];
    const auto it=p->properties.doubles.find(kOfxParamPropDefault);
    return it!=p->properties.doubles.end() && it->second.size()>channel ?
           it->second[channel] : 0.0;
}
OfxStatus getValueVA(OfxParamHandle h,va_list& args) {
    auto* p=asParameter(h);
    const auto& t=p->type;
    if(t==kOfxParamTypeString) {
        auto** value=va_arg(args,char**);
        *value=const_cast<char*>(readText(p));
    } else if(t==kOfxParamTypeInteger || t==kOfxParamTypeBoolean ||
              t==kOfxParamTypeChoice) {
        auto* value=va_arg(args,int*);
        *value=readInteger(p);
    } else if(t==kOfxParamTypeDouble) {
        auto* value=va_arg(args,double*);
        *value=readNumber(p,0);
    } else if(t==kOfxParamTypeDouble2D) {
        for(int i=0;i<2;i++) {
            auto* value=va_arg(args,double*);
            *value=readNumber(p,i);
        }
    } else if(t==kOfxParamTypeRGBA) {
        for(int i=0;i<4;i++) {
            auto* value=va_arg(args,double*);
            *value=readNumber(p,i);
        }
    } else return kOfxStatErrUnsupported;
    return kOfxStatOK;
}
OfxStatus getValue(OfxParamHandle h,...) {
    va_list args;
    va_start(args,h);
    const auto status=getValueVA(h,args);
    va_end(args);
    return status;
}
OfxStatus getValueAtTime(OfxParamHandle h,OfxTime time,...) {
    (void)time;
    va_list args;
    va_start(args,time);
    const auto status=getValueVA(h,args);
    va_end(args);
    return status;
}
OfxStatus setValueVA(OfxParamHandle h,va_list& args) {
    auto* p=asParameter(h);
    const auto& t=p->type;
    p->hasValue=true;
    if(t==kOfxParamTypeString) {
        const auto* text=va_arg(args,const char*);
        p->text=text?text:"";
    } else if(t==kOfxParamTypeInteger || t==kOfxParamTypeBoolean ||
              t==kOfxParamTypeChoice) {
        p->integer=va_arg(args,int);
    } else if(t==kOfxParamTypeDouble) {
        p->numbers={va_arg(args,double)};
    } else if(t==kOfxParamTypeDouble2D) {
        const double a=va_arg(args,double),b=va_arg(args,double);
        p->numbers={a,b};
    } else if(t==kOfxParamTypeRGBA) {
        p->numbers.clear();
        for(int i=0;i<4;i++)p->numbers.push_back(va_arg(args,double));
    } else return kOfxStatErrUnsupported;
    return kOfxStatOK;
}
OfxStatus setValue(OfxParamHandle h,...) {
    va_list args;
    va_start(args,h);
    const auto status=setValueVA(h,args);
    va_end(args);
    return status;
}
OfxStatus effectGetProps(OfxImageEffectHandle h,OfxPropertySetHandle* out) {
    *out=asProps(&asEffect(h)->properties);return kOfxStatOK;
}
OfxStatus effectGetParams(OfxImageEffectHandle h,OfxParamSetHandle* out) {
    *out=paramSet(asEffect(h));return kOfxStatOK;
}
OfxStatus clipDefine(OfxImageEffectHandle h,const char*,OfxPropertySetHandle* out) {
    *out=asProps(&asEffect(h)->outputProps);return kOfxStatOK;
}
OfxStatus clipGetHandle(OfxImageEffectHandle h,const char*,
                        OfxImageClipHandle* out,OfxPropertySetHandle*) {
    *out=clipHandle(asEffect(h));return kOfxStatOK;
}
OfxStatus clipGetImage(OfxImageClipHandle h,OfxTime,const OfxRectD*,
                       OfxPropertySetHandle* out) {
    auto* e=reinterpret_cast<Effect*>(h);
    e->frameProps=Properties{};
    for(int i=0;i<4;i++) {
        const int bounds[4]={0,0,640,360};
        setInt(asProps(&e->frameProps),kOfxImagePropBounds,i,bounds[i]);
    }
    setInt(asProps(&e->frameProps),kOfxImagePropRowBytes,0,640*4);
    setPointer(asProps(&e->frameProps),kOfxImagePropData,0,e->frame.data());
    setString(asProps(&e->frameProps),kOfxImageEffectPropPixelDepth,0,kOfxBitDepthByte);
    setString(asProps(&e->frameProps),kOfxImageEffectPropComponents,0,kOfxImageComponentRGBA);
    *out=asProps(&e->frameProps);return kOfxStatOK;
}
OfxStatus clipReleaseImage(OfxPropertySetHandle) {return kOfxStatOK;}

OfxPropertySuiteV1 propertySuite{};
OfxParameterSuiteV1 parameterSuite{};
OfxImageEffectSuiteV1 imageSuite{};
Properties hostProps;
const void* fetchSuite(OfxPropertySetHandle,const char* name,int version) {
    if(version!=1)return nullptr;
    if(!std::strcmp(name,kOfxPropertySuite))return &propertySuite;
    if(!std::strcmp(name,kOfxParameterSuite))return &parameterSuite;
    if(!std::strcmp(name,kOfxImageEffectSuite))return &imageSuite;
    return nullptr;
}
void initializeSuites() {
    propertySuite.propSetString=&setString;
    propertySuite.propSetDouble=&setDouble;
    propertySuite.propSetInt=&setInt;
    propertySuite.propSetPointer=&setPointer;
    propertySuite.propSetDoubleN=&setDoubleN;
    propertySuite.propSetIntN=&setIntN;
    propertySuite.propGetString=&getString;
    propertySuite.propGetDouble=&getDouble;
    propertySuite.propGetInt=&getInt;
    propertySuite.propGetPointer=&getPointer;
    propertySuite.propGetDoubleN=&getDoubleN;
    propertySuite.propGetIntN=&getIntN;
    parameterSuite.paramDefine=&defineParam;
    parameterSuite.paramGetHandle=&getParam;
    parameterSuite.paramGetValue=&getValue;
    parameterSuite.paramGetValueAtTime=&getValueAtTime;
    parameterSuite.paramSetValue=&setValue;
    imageSuite.getPropertySet=&effectGetProps;
    imageSuite.getParamSet=&effectGetParams;
    imageSuite.clipDefine=&clipDefine;
    imageSuite.clipGetHandle=&clipGetHandle;
    imageSuite.clipGetImage=&clipGetImage;
    imageSuite.clipReleaseImage=&clipReleaseImage;
}

struct Module {
#if defined(_WIN32)
    HMODULE module=nullptr;
    explicit Module(const char* path) : module(LoadLibraryA(path)) {
        if(!module)throw std::runtime_error("LoadLibrary failed");
    }
    void* symbol(const char* name) {
        return reinterpret_cast<void*>(GetProcAddress(module,name));
    }
    ~Module(){if(module)FreeLibrary(module);}
#else
    void* module=nullptr;
    explicit Module(const char* path) : module(dlopen(path,RTLD_NOW|RTLD_LOCAL)) {
        if(!module)throw std::runtime_error(std::string("dlopen failed: ")+dlerror());
    }
    void* symbol(const char* name) {return dlsym(module,name);}
    ~Module(){if(module)dlclose(module);}
#endif
};
int checks=0;
void check(bool passed,const char* why) {
    ++checks;
    if(!passed)throw std::runtime_error(why);
}
void changed(OfxPlugin* plugin,Effect& e,const char* name) {
    Properties args;
    setString(asProps(&args),kOfxPropType,0,kOfxTypeParameter);
    setString(asProps(&args),kOfxPropName,0,name);
    setString(asProps(&args),kOfxPropChangeReason,0,kOfxChangeUserEdited);
    const auto status=plugin->mainEntry(kOfxActionInstanceChanged,effectHandle(&e),
                                         asProps(&args),nullptr);
    check(status==kOfxStatOK,"OpenFX instanceChanged returned failure");
}
void text(Effect& e,const char* name,const std::string& value) {
    auto it=e.params.find(name);
    check(it!=e.params.end(),"expected Inspector text parameter");
    check(setValue(paramHandle(it->second.get()),value.c_str())==kOfxStatOK,
          "Inspector string setting");
}
void integer(Effect& e,const char* name,int value) {
    auto it=e.params.find(name);
    check(it!=e.params.end(),"expected Inspector integer parameter");
    check(setValue(paramHandle(it->second.get()),value)==kOfxStatOK,
          "Inspector index setting");
}
std::string currentText(Effect& e,const char* name) {
    auto it=e.params.find(name);
    check(it!=e.params.end(),"expected status or state parameter");
    return readText(it->second.get());
}

} // namespace

int main(int argc,char** argv) {
    try {
        if(!(argc==2 || (argc==3 && std::strcmp(argv[2],"--missing-data")==0)))
            throw std::invalid_argument("usage: ofx_contract_tests <plugin.ofx> [--missing-data]");
        initializeSuites();
        Module module(argv[1]);
        using NumberFn=int (*)();
        using PluginFn=OfxPlugin* (*)(int);
        auto number=reinterpret_cast<NumberFn>(module.symbol("OfxGetNumberOfPlugins"));
        auto fetch=reinterpret_cast<PluginFn>(module.symbol("OfxGetPlugin"));
        check(number && fetch,"required native OpenFX ABI exports present");
        check(number()==1,"exactly one CartoRig OpenFX plugin");
        OfxPlugin* plugin=fetch(0);
        check(plugin && std::string(plugin->pluginIdentifier)=="org.cartorig.atomic.Map",
              "plugin identity must be new and stable");
        OfxHost host{asProps(&hostProps),fetchSuite};
        plugin->setHost(&host);
        check(plugin->mainEntry(kOfxActionLoad,nullptr,nullptr,nullptr)==kOfxStatOK,
              "OpenFX host loaded suites");
        Effect e;
        const double project[2]={640,360};
        setDoubleN(asProps(&e.properties),kOfxImageEffectPropProjectSize,2,project);
        check(plugin->mainEntry(kOfxActionDescribe,effectHandle(&e),nullptr,nullptr)==kOfxStatOK,
              "OpenFX adapter descriptor");
        Properties context;
        setString(asProps(&context),kOfxImageEffectPropContext,0,
                  kOfxImageEffectContextGenerator);
        check(plugin->mainEntry(kOfxImageEffectActionDescribeInContext,effectHandle(&e),
                                 asProps(&context),nullptr)==kOfxStatOK,
              "OpenFX generator parameters defined");
        check(e.params.count("locationSearch") && e.params.count("sceneSnapshot") &&
              e.params.count("addRegion") && e.params.count("addRoute"),
              "native Inspector has geographic authoring controls");
        check(plugin->mainEntry(kOfxActionCreateInstance,effectHandle(&e),nullptr,nullptr)==kOfxStatOK,
              "OpenFX instance creation and catalog availability");

        if(argc==3) {
            check(currentText(e,"statusMessage").find("CATALOG ERROR")!=std::string::npos,
                  "data-load failure visible in native Inspector Info");
            Properties args;
            setDouble(asProps(&args),kOfxPropTime,0,0.0);
            const int renderBounds[4]={0,0,640,360};
            setIntN(asProps(&args),kOfxImageEffectPropRenderWindow,4,renderBounds);
            const double renderScale[2]={1,1};
            setDoubleN(asProps(&args),kOfxImageEffectPropRenderScale,2,renderScale);
            check(plugin->mainEntry(kOfxImageEffectActionRender,effectHandle(&e),
                                    asProps(&args),nullptr)==kOfxStatOK,
                  "missing geographic data must not cause hard render failure");
            const auto center=4u*(180u*640u+320u);
            check(e.frame[center] > 50 && e.frame[center+2] > 50 &&
                  e.frame[center+1] == 0 && e.frame[center+3] == 255,
                  "missing data shows opaque magenta diagnostic, never transparent black");
            integer(e,"diagnosticPattern",1);
            changed(plugin,e,"diagnosticPattern");
            check(plugin->mainEntry(kOfxImageEffectActionRender,effectHandle(&e),
                                    asProps(&args),nullptr)==kOfxStatOK,
                  "diagnostic test pattern works independent of geographic data");
            const auto yellow=4u*(180u*640u+300u);
            check(e.frame[yellow] == 255 && e.frame[yellow+1] == 255,
                  "diagnostic pattern reveals live OFX pixel pipeline");
            check(plugin->mainEntry(kOfxActionDestroyInstance,effectHandle(&e),
                                    nullptr,nullptr)==kOfxStatOK,
                  "missing-data instance destroyed cleanly");
            check(plugin->mainEntry(kOfxActionUnload,nullptr,nullptr,nullptr)==kOfxStatOK,
                  "host unloads missing-data scenario");
            std::cout<<"PASS: "<<checks<<" missing-data and diagnostic-pattern ABI checks\n";
            return 0;
        }

        text(e,"locationSearch","Rio de Janeiro");
        integer(e,"locationType",2);
        integer(e,"locationMatch",1);
        changed(plugin,e,"locationSearch");
        check(currentText(e,"locationResults").find("Rio de Janeiro")!=std::string::npos,
              "native Inspector query returns typed offline matches");
        changed(plugin,e,"addRegion");
        check(currentText(e,"sceneSnapshot").find("REGION")!=std::string::npos,
              "Add Region persists actual geographic scene object");

        text(e,"locationSearch","São Paulo");
        integer(e,"locationType",3);
        changed(plugin,e,"locationSearch");
        changed(plugin,e,"focusCamera");
        const auto& center=e.params.at("cameraCenter")->numbers;
        check(center.size()==2 && std::abs(center[0]+46.6)<1e-5,
              "camera focuses selected city and not the state");

        changed(plugin,e,"addRoute");
        check(currentText(e,"sceneSnapshot").find("ROUTE")==std::string::npos,
              "no route is created without an editor-selected endpoint");
        text(e,"routeOrigin","Brasília");
        text(e,"routeState","Amapá");
        text(e,"routeArrivalCity","Macapá");
        changed(plugin,e,"addRoute");
        check(currentText(e,"sceneSnapshot").find("ROUTE")!=std::string::npos,
              "explicit route from Brasília to user-selected Macapá in Amapá added");

        Properties renderArgs;
        setDouble(asProps(&renderArgs),kOfxPropTime,0,0);
        const int window[4]={0,0,640,360};
        setIntN(asProps(&renderArgs),kOfxImageEffectPropRenderWindow,4,window);
        const double scale[2]={1,1};
        setDoubleN(asProps(&renderArgs),kOfxImageEffectPropRenderScale,2,scale);
        check(plugin->mainEntry(kOfxImageEffectActionRender,effectHandle(&e),
                                asProps(&renderArgs),nullptr)==kOfxStatOK,
              "native OpenFX render callback creates geographic RGBA frame");
        bool opaque=false, nonUniform=false;
        const auto& bytes=e.frame;
        for(std::size_t i=0;i+7<bytes.size();i+=4) {
            if(bytes[i+3])opaque=true;
            if(bytes[i]!=bytes[0] || bytes[i+1]!=bytes[1] || bytes[i+2]!=bytes[2])
                nonUniform=true;
        }
        check(opaque && nonUniform,"render actually draws more than one color");


        // A project restore/plugin-initiated callback for an action button
        // is not a real user click and must NOT create a duplicate region.
        {
            const std::string before=currentText(e,"sceneSnapshot");
            Properties notUser;
            setString(asProps(&notUser),kOfxPropName,0,"addRegion");
            setString(asProps(&notUser),kOfxPropChangeReason,0,kOfxChangePluginEdited);
            check(plugin->mainEntry(kOfxActionInstanceChanged,effectHandle(&e),
                                    asProps(&notUser),nullptr)==kOfxStatOK,
                  "non-user action callback safely ignored");
            check(currentText(e,"sceneSnapshot")==before,
                  "restoring saved projects cannot accidentally add objects");
        }
        const std::string persisted=currentText(e,"sceneSnapshot");
        check(plugin->mainEntry(kOfxActionDestroyInstance,effectHandle(&e),nullptr,nullptr)==kOfxStatOK,
              "host can destroy original plugin instance");
        check(plugin->mainEntry(kOfxActionCreateInstance,effectHandle(&e),nullptr,nullptr)==kOfxStatOK,
              "host can recreate plugin instance");
        check(currentText(e,"sceneSnapshot")==persisted,"scene survived re-instantiation");
        check(plugin->mainEntry(kOfxActionDestroyInstance,effectHandle(&e),nullptr,nullptr)==kOfxStatOK,
              "host can destroy reopened instance");
        check(plugin->mainEntry(kOfxActionUnload,nullptr,nullptr,nullptr)==kOfxStatOK,
              "host can unload plugin");
        std::cout<<"PASS: "<<checks<<" actual OpenFX binary contract checks (synthetic host)\n";
        return 0;
    } catch(const std::exception& error) {
        std::cerr<<"FAIL: "<<error.what()<<" at assertion "<<checks<<"\n";
        return 1;
    }
}
