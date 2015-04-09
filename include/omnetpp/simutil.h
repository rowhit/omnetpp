//==========================================================================
//  SIMUTIL.H - part of
//                     OMNeT++/OMNEST
//            Discrete System Simulation in C++
//
//
//  Utility functions
//
//==========================================================================

/*--------------------------------------------------------------*
  Copyright (C) 1992-2015 Andras Varga
  Copyright (C) 2006-2015 OpenSim Ltd.

  This file is distributed WITHOUT ANY WARRANTY. See the file
  `license' for details on this and other legal matters.
*--------------------------------------------------------------*/

#ifndef __OMNETPP_SIMUTIL_H
#define __OMNETPP_SIMUTIL_H

#include <string.h>  // for strlen, etc.
#include <stdarg.h>  // for va_list
#include <stdio.h>   // for sprintf
#include <stdlib.h>  // for gcvt
#include <typeinfo>  // for type_info
#include <string>    // for std::string
#include "platdep/platmisc.h" // for gcvt, etc
#include "simkerneldefs.h"
#include "errmsg.h"

NAMESPACE_BEGIN

// forward declarations
class cComponent;

// logically belongs to csimulation.h but must be here because of declaration order
enum {CTX_NONE, CTX_BUILD, CTX_INITIALIZE, CTX_EVENT, CTX_FINISH, CTX_CLEANUP};

/**
 * Some of these functions are similar to \<string.h\> functions, with the
 * exception that they also accept NULL pointers as empty strings (""),
 * and use operator new instead of malloc(). It is recommended to use these
 * functions instead of the original \<string.h\> functions.
 *
 * @ingroup Functions
 * @defgroup FunctionsString String-related
 */
//@{
/**
 * Same as the standard strlen() function, except that does not crash
 * on NULL pointers but returns 0.
 */
inline int opp_strlen(const char *);

/**
 * Duplicates the string, using <tt>new char[]</tt>. For NULLs and empty
 * strings it returns NULL.
 */
inline char *opp_strdup(const char *);

/**
 * Same as the standard strcpy() function, except that NULL pointers
 * in the second argument are treated like pointers to a null string ("").
 */
inline char *opp_strcpy(char *,const char *);

/**
 * Same as the standard strcmp() function, except that NULL pointers
 * are treated exactly as empty strings ("").
 */
inline int opp_strcmp(const char *, const char *);

/**
 * Copies src string into desc, and if its length would exceed maxlen,
 * it is truncated with an ellipsis. For example, <tt>opp_strprettytrunc(buf,
 * "long-long",6)</tt> yields <tt>"lon..."</tt>.
 */
SIM_API char *opp_strprettytrunc(char *dest, const char *src, unsigned maxlen);

//@}

/**
 * DEPRECATED: Error handling functions.
 */
//@{

/**
 * DEPRECATED: use <tt>throw cRuntimeError(...)</tt> instead!
 *
 * Terminates the simulation with an error message.
 */
SIM_API void opp_error(OppErrorCode errcode,...);

/**
 * DEPRECATED: use <tt>throw cRuntimeError(...)</tt> instead!
 *
 * Same as function with the same name, but using custom message string.
 * To be called like printf().
 */
SIM_API void opp_error(const char *msg,...);

/**
 * This method can be used to report non-fatal discrepancies to the user.
 * Generally, warnings should VERY RARELY be used, if ever.
 * Argument list is like printf().
 *
 * Unlike in earlier versions, the user will NOT be offered the possibility
 * to stop the simulation. (In Cmdenv, warnings will be written
 * to the standard error, and in Tkenv it will probably pop up an
 * [OK] dialog.
 */
SIM_API void opp_warning(OppErrorCode errcode,...);

/**
 * This method can be used to report non-fatal discrepancies to the user.
 * Generally, warnings should VERY RARELY be used, if ever.
 * Argument list works like printf().
 *
 * Unlike in earlier versions, the user will NOT be offered the possibility
 * to stop the simulation. (In Cmdenv, warnings will be written
 * to the standard error, and in Tkenv it will probably pop up an
 * [OK] dialog.
 */
SIM_API void opp_warning(const char *msg,...);

/**
 * DEPRECATED.
 *
 * Print message and set error number.
 */
SIM_API void opp_terminate(OppErrorCode errcode,...);

/**
 * DEPRECATED.
 *
 * Same as function with the same name, but using custom message string.
 * To be called like printf().
 */
SIM_API void opp_terminate(const char *msg,...);
//@}

// INTERNAL: returns the name of a C++ type, correcting the quirks of various compilers.
SIM_API const char *opp_demangle_typename(const char *mangledName);

// INTERNAL: returns the name of a C++ type, correcting the quirks of various compilers.
SIM_API const char *opp_typename(const std::type_info& t);


/**
 * Denotes module class member function as callable from other modules.
 *
 * Usage: <tt>Enter_Method(fmt, arg1, arg2...);</tt>
 *
 * Example: <tt>Enter_Method("requestPacket(%d)",n);</tt>
 *
 * The macro should be put at the top of every module member function
 * that may be called from other modules. This macro arranges to
 * temporarily switch the context to the called module (the old context
 * will be restored automatically when the method returns),
 * and also lets the graphical user interface animate the method call.
 *
 * The argument(s) should specify the method name (and parameters) --
 * it will be used for the animation. The argument list works as in
 * <tt>printf()</tt>, so it is easy to include the actual parameter values.
 *
 * @see Enter_Method_Silent() macro
 */
#define Enter_Method  OPP::cMethodCallContextSwitcher __ctx(this); __ctx.methodCall

/**
 * Denotes module class member function as callable from other modules.
 * This macro is similar to the Enter_Method() macro, only it does not animate
 * the call on the GUI; the call is still recorded into the the event log file.
 *
 * The macro may be called with or without arguments. When called with arguments,
 * they should be a printf-style format string, and parameters to be substituted
 * into it; the resulting string should contain the method name and the actual
 * arguments.
 *
 * Usage: <tt>Enter_Method_Silent();</tt>, <tt>Enter_Method_Silent(fmt, arg1, arg2...);</tt>
 *
 * Example: <tt>Enter_Method_Silent("getRouteFor(address=%d)",address);</tt>
 *
 * @see Enter_Method() macro
 */
#define Enter_Method_Silent  OPP::cMethodCallContextSwitcher __ctx(this); __ctx.methodCallSilent

/**
 * The constructor switches the context to the given component, and the
 * destructor restores the original context.
 *
 * @see cSimulation::getContextModule(), cSimulation::setContextModule()
 * @ingroup Internals
 */
class SIM_API cContextSwitcher
{
  protected:
    cComponent *callerContext;
  public:
    /**
     * Switches context to the given module
     */
    cContextSwitcher(const cComponent *newContext);

    /**
     * Restores the original context
     */
    ~cContextSwitcher();
};

/**
 * Internal class. May only be used via the Enter_Method() and Enter_Method_Silent() macros!
 * @ingroup Internals
 */
class SIM_API cMethodCallContextSwitcher : public cContextSwitcher
{
  private:
    static int depth;

  public:
    /**
     * Switches context to the given module
     */
    //TODO store previous frame, __FILE__, __LINE__, __FUNCTION__ too, at least in debug builds?
    cMethodCallContextSwitcher(const cComponent *newContext);

    /**
     * Restores the original context
     */
    ~cMethodCallContextSwitcher();

    /**
     * Various ways to tell the user interface about the method call so that
     * the call can be animated, recorded into the event log, etc.
     */
    void methodCall(const char *methodFmt,...);
    void methodCallSilent(const char *methodFm,...);
    void methodCallSilent();

    /**
     * Returns the depth of Enter_Method[_Silent] calls
     */
    static int getDepth() {return depth;}
};

/**
 * The constructor switches the context type, and the destructor restores
 * the original context type.
 *
 * @see cSimulation::getContextModule(), cSimulation::setContextModule()
 * @ingroup Internals
 */
class SIM_API cContextTypeSwitcher
{
  private:
    int savedcontexttype;

  public:
    /**
     * Switches the context type (see CTX_xxx constants)
     */
    cContextTypeSwitcher(int contexttype);

    /**
     * Restores the original context type
     */
    ~cContextTypeSwitcher();
};

//==========================================================================
//=== Implementation of utility functions:

#ifndef __OMNETPP_STRINGUTIL_H   // avoid clash with similar defs in common/stringutil.h

inline char *opp_strcpy(char *s1,const char *s2)
{
    return strcpy(s1, s2 ? s2 : "");
}

inline int opp_strlen(const char *s)
{
    return s ? strlen(s) : 0;
}

inline char *opp_strdup(const char *s)
{
    if (!s || !s[0]) return NULL;
    char *p = new char[strlen(s)+1];
    strcpy(p,s);
    return p;
}

inline char *opp_strdup(const char *s, int len)
{
    if (!s || !s[0]) return NULL;
    char *p = new char[len+1];
    strncpy(p,s,len);
    p[len] = 0;
    return p;
}

inline int opp_strcmp(const char *s1, const char *s2)
{
    if (s1)
        return s2 ? strcmp(s1,s2) : (*s1 ? 1 : 0);
    else
        return (s2 && *s2) ? -1 : 0;
}

#endif //_STRINGUTIL_H_

// internally used: appends [num] to the given string
inline void opp_appendindex(char *s, unsigned int i)
{
   while (*s) s++;
   *s++ = '[';
   if (i<10)
       {*s++ = '0'+i; *s++=']'; *s=0; return;}
   if (i<100)
       {*s++ = '0'+i/10; *s++='0'+i%10; *s++=']'; *s=0; return;}
   sprintf(s,"%d]",i);
}

inline long double_to_long(double d)
{
    // gcc feature: if double d=0xc0000000, (long)d yields 0x80000000 !
    // This only happens with long: unsigned long is OK.
    // This causes trouble if we in fact want to cast this long to unsigned long, see NED_expr_2.test.
    // Workaround follows. Note: even the ul variable is needed: when inlining it, gcc will do the wrong cast!
    long l = (long)d;
    unsigned long ul = (unsigned long)d;
    return d<0 ? l : ul;
}

// internal
inline std::string double_to_str(double t)
{
#if __cplusplus >= 201103L
   return std::to_string(t);
#else
   char buf[32];
   return gcvt(t,16,buf);
#endif
}


NAMESPACE_END


#endif

