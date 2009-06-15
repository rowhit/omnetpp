%module Simkernel

%{
#include "omnetpp.h"
#include "guienvdefs.h"
#include "innerclasses.h"
#include "visitor.h"

// we use RegisterNatives(), so no need to export generated functions from the DLL
#undef JNICALL
#define JNICALL /*nothing*/
#undef SWIGEXPORT
#define SWIGEXPORT /*nothing*/
%}

%include commondefs.i
//%include simtime.i
%include simtime_tmp.i   //XXX until we rewrite java code to use bigdecimal
%include displaystring.i
%include cobject.i
%include exception.i

%pragma(java) jniclasscode=%{
  static {
    try {
      org.omnetpp.common.util.ReflectionUtils.invokeStaticMethod(Class.forName("GUIEnvHelper"), "registerNatives");
    }
    catch (Throwable e) {
      System.err.println("FATAL: registration of SimkernelJNI native methods failed: " + e);
      System.exit(1);
    }
  }
%}

%typemap(javacode) cEnvir %{
  public cEnvir disown() {
    swigCMemOwn = false;
    return this;
  }
%}

%include "std_common.i"
%include "std_string.i"
%include "std_vector.i"

namespace std {
   %template(IntVector) vector<int>;
   %template(StringVector) vector<std::string>;
   %template(PStringVector) vector<const char *>;
   %template(cObjectVector) vector<cObject *>;
}

// hide some macros from swig (copied from nativelibs/common.i)
#define COMMON_API
#define ENVIR_API
#define GUIENV_API
#define OPP_DLLEXPORT
#define OPP_DLLIMPORT

#define NAMESPACE_BEGIN
#define NAMESPACE_END
#define USING_NAMESPACE
#define OPP

#define _OPPDEPRECATED


#pragma SWIG nowarn=516;  // "Overloaded method x ignored. Method y used."

// ignore/rename some operators (some have method equivalents)
%rename(assign) operator=;
%rename(plusPlus) operator++;
%ignore operator +=;
%ignore operator [];
%ignore operator <<;
%ignore operator ();

// ignore conversion operators (they all have method equivalents)
%ignore operator bool;
%ignore operator const char *;
%ignore operator char;
%ignore operator unsigned char;
%ignore operator int;
%ignore operator unsigned int;
%ignore operator long;
%ignore operator unsigned long;
%ignore operator double;
%ignore operator long double;
%ignore operator void *;
%ignore operator cObject *;
%ignore operator cXMLElement *;
%ignore cSimulation::operator=;

%ignore cEnvir::printf;
%ignore cGate::setChannel;

// ignore methods that are useless from Java
%ignore parsimPack;
%ignore parsimUnpack;

// ignore non-inspectable and deprecated classes
%ignore cCommBuffer;
%ignore cContextSwitcher;
%ignore cContextTypeSwitcher;
%ignore cOutputVectorManager;
%ignore cOutputScalarManager;
%ignore cOutputSnapshotManager;
%ignore cScheduler;
%ignore cRealTimeScheduler;
%ignore cParsimCommunications;
%ignore ModNameParamResolver;
%ignore StringMapParamResolver;
%ignore cSubModIterator;
%ignore cLinkedList;

// ignore global variables but add accessors for them
%ignore defaultList;
%ignore componentTypes;
%ignore nedFunctions;
%ignore classes;
%ignore enums;
%ignore classDescriptors;
%ignore configOptions;

%{
cDefaultList& getDefaultList() {return defaultList;}
cRegistrationList *getRegisteredComponentTypes() {return componentTypes.getInstance();}
cRegistrationList *getRegisteredNedFunctions() {return nedFunctions.getInstance();}
cRegistrationList *getRegisteredClasses() {return classes.getInstance();}
cRegistrationList *getRegisteredEnums() {return enums.getInstance();}
cRegistrationList *getRegisteredClassDescriptors() {return classDescriptors.getInstance();}
cRegistrationList *getRegisteredConfigOptions() {return configOptions.getInstance();}
%}
cDefaultList& getDefaultList();
cRegistrationList *getRegisteredComponentTypes();
cRegistrationList *getRegisteredNedFunctions();
cRegistrationList *getRegisteredClasses();
cRegistrationList *getRegisteredEnums();
cRegistrationList *getRegisteredClassDescriptors();
cRegistrationList *getRegisteredConfigOptions();

// ignore macros that confuse swig
/*
#define GATEID_LBITS  20
#define GATEID_HBITS  (8*sizeof(int)-GATEID_LBITS)   // usually 12
#define GATEID_HMASK  ((~0)<<GATEID_LBITS)           // usually 0xFFF00000
#define GATEID_LMASK  (~GATEID_HMASK)                // usually 0x000FFFFF
*/
%ignore MAX_VECTORGATES;
%ignore MAX_SCALARGATES;
%ignore MAX_VECTORGATESIZE;


// ignore problematic methods/class
%ignore cDynamicExpression::evaluate; // returns inner type (swig is not prepared to handle them)
%ignore cDensityEstBase::getCellInfo; // returns inner type (swig is not prepared to handle them)
%ignore cKSplit;  // several methods are problematic
%ignore cPacketQueue;  // Java compile problems (cMessage/cPacket conversion)

%ignore critfunc_const;
%ignore critfunc_depth;
%ignore divfunc_const;
%ignore divfunc_babak;

%ignore cMsgPar::operator=(void*);

%typemap(javacode) cClassDescriptor %{
  public static long getCPtr(cObject obj) { // make method public
    return cObject.getCPtr(obj);
  }
%}

%extend cClassDescriptor {
   cObject *getFieldAsCObject(void *object, int field, int index) {
       return self->getFieldIsCObject(object,field) ? (cObject *)self->getFieldStructPointer(object,field,index) : NULL;
   }
}

%ignore LogBuffer::getEntries; //XXX temp

// typemaps to wrap GUIEnv::setJCallback(JNIEnv *jenv, jobject jcallbackobj):
// %typemap(in, numinputs=0): unfortunately, generated java code doesn't compile

%typemap(in) JNIEnv* "$1 = jenv;";  // in Java, just pass "null" for this argument...
%typemap(in) jobject "$1 = j$1;";

//XXX temporarily disabled; TO BE PUT BACK: %typemap(javainterfaces) cSimulation "org.omnetpp.common.simulation.model.IRuntimeSimulation";

//XXX temporarily disabled; TO BE PUT BACK: %typemap(javainterfaces) cModule "org.omnetpp.common.simulation.model.IRuntimeModule";

/*
%typemap(javaimports) cModule
  "import org.omnetpp.common.displaymodel.DisplayString;\n"
  "import org.omnetpp.common.displaymodel.IDisplayString;";
*/
%typemap(javacode) cModule %{
//  public IDisplayString getDisplayString() {
//    return new DisplayString(null, null, displayString().getString());
//  }
%};

//XXX temporarily disabled; TO BE PUT BACK: %typemap(javainterfaces) cGate "org.omnetpp.common.simulation.model.IRuntimeGate";

/*
%typemap(javaimports) cGate
  "import org.omnetpp.common.displaymodel.DisplayString;\n"
  "import org.omnetpp.common.displaymodel.IDisplayString;";

%typemap(javacode) cGate %{
  public IDisplayString getDisplayString() {
    return new DisplayString(null, null, displayString().getString());
  }
%};
*/

//XXX temporarily disabled; TO BE PUT BACK: %typemap(javainterfaces) cMessage "org.omnetpp.common.simulation.model.IRuntimeMessage";


%{

#include <direct.h>
inline void changeToDir(const char *dir)  //XXX
{
    printf("changing to: %s\n", dir);
    _chdir(dir);

    //char buffer[_MAX_PATH];
    //if (_getcwd( buffer, _MAX_PATH)==NULL)
    //   strcpy(buffer,"???");
    //printf("current working directory: %s\n", buffer);
}

#include "startup.h"  // from src/envir
inline int setupUserInterface(const std::vector<std::string>& args)
{
    int argc = args.size();
    const char **argv = new const char *[argc];
    for (int i=0; i<argc; i++)
        argv[i] = args[i].c_str();
    return setupUserInterface(argc, (char **)argv);
}

%};

void changeToDir(const char *dir); //XXX
int setupUserInterface(const std::vector<std::string>& args);

// Cast etc from jsimplemodule
%define BASECLASS(CLASS)
%ignore CLASS::CLASS(const CLASS&);
%ignore CLASS::operator=(const CLASS&);
%enddef

%define DERIVEDCLASS(CLASS,BASECLASS)
%ignore CLASS::CLASS(const CLASS&);
%ignore CLASS::operator=(const CLASS&);
%extend CLASS {
  static CLASS *cast(BASECLASS *obj) {return dynamic_cast<CLASS *>(obj);}
}
%enddef

//TODO: for all cObject-based classes
DERIVEDCLASS(cComponent,cObject);
DERIVEDCLASS(cModule,cObject);
DERIVEDCLASS(Channel,cObject);
DERIVEDCLASS(cGate,cObject);
DERIVEDCLASS(cPar,cObject);
DERIVEDCLASS(cQueue,cObject);
DERIVEDCLASS(cMessage,cObject);
DERIVEDCLASS(cPacket,cObject);

DERIVEDCLASS(cComponentType,cObject);
DERIVEDCLASS(cModuleType,cObject);
DERIVEDCLASS(cChannelType,cObject);

DERIVEDCLASS(EnvirBase,cEnvir);
DERIVEDCLASS(GUIEnv,cEnvir);
DERIVEDCLASS(cConfigurationEx,cConfiguration);
DERIVEDCLASS(cException,std::exception);
DERIVEDCLASS(cRuntimeError,std::exception);
DERIVEDCLASS(cTerminationException,std::exception);


%include "innerclasses.h"

%include "simkerneldefs.h"
%include "simtime.h"
%include "simtime_t.h"
%include "cobject.h"
%include "cnamedobject.h"
%include "cownedobject.h"
%include "cdefaultlist.h"
%include "ccomponent.h"
%include "cchannel.h"
%include "cdelaychannel.h"
%include "cdataratechannel.h"
%include "cmodule.h"
%include "ccoroutine.h"
%include "csimplemodule.h"
%include "ccompoundmodule.h"
%include "ccomponenttype.h"
%include "carray.h"
%include "clinkedlist.h"
%include "cqueue.h"
%include "cpacketqueue.h"
%include "cdetect.h"
%include "cstatistic.h"
%include "cstddev.h"
%include "cdensityestbase.h"
%include "chistogram.h"
%include "cksplit.h"
%include "cpsquare.h"
%include "cvarhist.h"
%include "ccoroutine.h"
%include "crng.h"
%include "clcg32.h"
%include "cmersennetwister.h"
%include "cclassfactory.h"
%include "ccommbuffer.h"
%include "cconfiguration.h"
%include "cconfigoption.h"
%include "cdisplaystring.h"
%include "cdynamicexpression.h"
%include "cenum.h"
%include "cenvir.h"
%include "cexception.h"
%include "cexpression.h"
%include "chasher.h"
%include "cfsm.h"
%include "cmathfunction.h"
%include "cgate.h"
%include "cmessage.h"
%include "cmsgpar.h"
%include "cmessageheap.h"
%include "cnedfunction.h"
%include "cnullenvir.h"
%include "coutvector.h"
%include "cpar.h"
%include "cparsimcomm.h"
%include "cproperty.h"
%include "cproperties.h"
%include "cscheduler.h"
%include "csimulation.h"
%include "cstringtokenizer.h"
%include "cclassdescriptor.h"
%include "ctopology.h"
%include "cvisitor.h"
%include "cwatch.h"
%include "cstlwatch.h"
%include "cxmlelement.h"
%include "distrib.h"
%include "envirext.h"
%include "errmsg.h"
%include "globals.h"
%include "onstartup.h"
%include "opp_string.h"
%include "random.h"
%include "cregistrationlist.h"
%include "regmacros.h"
%include "simutil.h"
%include "packing.h"
//%include "index.h"
//%include "mersennetwister.h"
//%include "compat.h"
//%include "cparimpl.h"
//%include "cboolparimpl.h"
//%include "cdoubleparimpl.h"
//%include "clongparimpl.h"
//%include "cstringparimpl.h"
//%include "cstringpool.h"
//%include "cxmlparimpl.h"
//%include "nedsupport.h"

%{
#include "envirbase.h"  //from src/envir
#include "visitor.h"
#include "logbuffer.h"
#include "logbufferview.h"
#include "jutil.h"
#include "guienv.h"
%}

%include "envirbase.h"  //from src/envir
%include "visitor.h"
%include "logbuffer.h"
%include "logbufferview.h"
%include "jutil.h"
%include "guienv.h"


