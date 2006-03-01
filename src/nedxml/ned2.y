/*===============================================================
 * File: ned2.y
 *
 *  Grammar for OMNeT++ NED-2.
 *
 *  Author: Andras Varga
 *
 *=============================================================*/

/*--------------------------------------------------------------*
  Copyright (C) 1992,2005 Andras Varga

  This file is distributed WITHOUT ANY WARRANTY. See the file
  `license' for details on this and other legal matters.
*--------------------------------------------------------------*/

/* Reserved words */
%token IMPORT PACKAGE PROPERTY
%token MODULE SIMPLE NETWORK CHANNEL INTERFACE CHANNELINTERFACE
%token EXTENDS LIKE WITHCPPCLASS
%token TYPES PARAMETERS GATES SUBMODULES CONNECTIONS ALLOWUNCONNECTED
%token DOUBLETYPE INTTYPE STRINGTYPE BOOLTYPE XMLTYPE FUNCTION TYPENAME
%token INPUT_ OUTPUT_ INOUT_
%token IF WHERE
%token RIGHTARROW LEFTARROW DBLARROW TO
%token TRUE_ FALSE_ THIS_ DEFAULT CONST_ SIZEOF INDEX_ XMLDOC

/* Other tokens: identifiers, numeric literals, operators etc */
%token NAME INTCONSTANT REALCONSTANT STRINGCONSTANT CHARCONSTANT
%token PLUSPLUS DOUBLEASTERISK
%token EQ NE GE LE
%token AND OR XOR NOT
%token BIN_AND BIN_OR BIN_XOR BIN_COMPL
%token SHIFT_LEFT SHIFT_RIGHT

%token INVALID_CHAR   /* just to generate parse error --VA */

/* Operator precedences (low to high) and associativity */
%left '?' ':'
%left AND OR XOR
%left EQ NE '>' GE '<' LE
%left BIN_AND BIN_OR BIN_XOR
%left SHIFT_LEFT SHIFT_RIGHT
%left '+' '-'
%left '*' '/' '%'
%right '^'
%left UMIN NOT BIN_COMPL

%start nedfile

/* requires at least bison 1.50 (tested with bison 2.1) */
%glr-parser

%{

#include <stdio.h>
#include <stdlib.h>
#include <stack>
#include "nedgrammar.h"
#include "nederror.h"

#define YYDEBUG 1           /* allow debugging */
#define YYDEBUGGING_ON 0    /* turn on/off debugging */

#if YYDEBUG != 0
#define YYERROR_VERBOSE     /* more detailed error messages */
#include <string.h>         /* YYVERBOSE needs it */
#endif

#define yylloc ned2yylloc
#define yyin ned2yyin
#define yyout ned2yyout
#define yyrestart ned2yyrestart
#define yy_scan_string ned2yy_scan_string
#define yy_delete_buffer ned2yy_delete_buffer
extern FILE *yyin;
extern FILE *yyout;
struct yy_buffer_state;
struct yy_buffer_state *yy_scan_string(const char *str);
void yy_delete_buffer(struct yy_buffer_state *);
void yyrestart(FILE *);
int yylex();
void yyerror (const char *s);
void resetlexer();

#include "nedparser.h"
#include "nedfilebuffer.h"
#include "nedelements.h"
#include "nedutil.h"
#include "nedyylib.h"

static struct NED2ParserState
{
    bool inTypes;
    bool inGroup;
    std::stack<NEDElement *> propertyscope; // top(): where to insert properties as we parse them
    std::stack<NEDElement *> blockscope;    // top(): where to insert parameters, gates, etc
    std::stack<NEDElement *> typescope;     // top(): as blockscope, but ignore submodules and connection channels

    /* tmp flags, used with param, gate and conn */
    int paramType;
    int gateType;
    bool isFunction;
    bool isDefault;
    int subgate;

    /* tmp flags, used with msg fields */
    bool isAbstract;
    bool isReadonly;

    /* NED-II: modules, channels */
    NedFileNode *nedfile;
    WhitespaceNode *whitespace;
    ImportNode *import;
    PropertyDeclNode *propertydecl;
    ExtendsNode *extends;
    InterfaceNameNode *interfacename;
    NEDElement *component;  // compound/simple module, module interface, channel or channel interface
    ParametersNode *parameters;
    ParamGroupNode *paramgroup;
    ParamNode *param;
    PatternNode *pattern;
    PropertyNode *property;
    PropertyKeyNode *propkey;
    TypesNode *types;
    GatesNode *gates;
    GateGroupNode *gategroup;
    GateNode *gate;
    SubmodulesNode *submods;
    SubmoduleNode *submod;
    ConnectionsNode *conns;
    ConnectionGroupNode *conngroup;
    ConnectionNode *conn;
    ChannelSpecNode *chanspec;
    WhereNode *where;
    LoopNode *loop;
    ConditionNode *condition;
} ps;

static void resetParserState()
{
    static NED2ParserState cleanps;
    ps = cleanps;
}

%}

%%

/*
 * Top-level components
 */
nedfile
        : packagedeclaration somedefinitions
        | somedefinitions
        ;

somedefinitions
        : somedefinitions definition
        |
        ;

definition
        : import
        | propertydecl
        | fileproperty
        | channeldefinition
        | channelinterfacedefinition
        | simplemoduledefinition
        | compoundmoduledefinition
        | networkdefinition
        | moduleinterfacedefinition
        ;

packagedeclaration         /* TBD package is currently not supported */
        : PACKAGE packagename ';'
        ;

packagename                /* TBD package is currently not supported */
        : packagename '.' NAME
        | NAME
        ;


/*
 * Import
 */
import
        : IMPORT STRINGCONSTANT ';'
                {
                  ps.import = (ImportNode *)createNodeWithTag(NED_IMPORT, ps.nedfile);
                  ps.import->setFilename(toString(trimQuotes(@2)));
                  //setComments(ps.import,@1);
                }
        ;

/*
 * Property declaration
 */
propertydecl
        : propertydecl_header opt_inline_properties ';'
        | propertydecl_header '(' opt_propertydecl_keys ')' opt_inline_properties ';'
        ;

propertydecl_header
        : PROPERTY '@' NAME
                {
                  ps.propertydecl = (PropertyDeclNode *)createNodeWithTag(NED_PROPERTY_DECL, ps.nedfile);
                  ps.propertydecl->setName(toString(@3));
                  //setComments(ps.propertydecl,@1);
                }
        ;

opt_propertydecl_keys
        : propertydecl_keys
        |
        ;

propertydecl_keys
        : propertydecl_keys ',' propertydecl_key
        | propertydecl_key
        ;

propertydecl_key
        : NAME
                {
                  ps.propkey = (PropertyKeyNode *)createNodeWithTag(NED_PROPERTY_KEY, ps.propertydecl);
                  ps.propkey->setKey(toString(@1));
                }
        ;

/*
 * File Property
 */
fileproperty
        : property_namevalue ';'
        ;

/*
 * Channel
 */
channeldefinition
        : channelheader '{'
                {
                  ps.typescope.push(ps.component);
                  ps.blockscope.push(ps.component);
                  ps.parameters = (ParametersNode *)createNodeWithTag(NED_PARAMETERS, ps.component);
                  ps.parameters->setIsImplicit(true);
                  ps.propertyscope.push(ps.parameters);
                }
            opt_paramblock
          '}' opt_semicolon
                {
                  ps.propertyscope.pop();
                  ps.blockscope.pop();
                  ps.typescope.pop();
                  setTrailingComment(ps.component,@4);
                  if (np->getStoreSourceFlag())
                      storeComponentSourceCode(ps.component, @$);
                }
        ;

channelheader
        : CHANNEL NAME
                {
                  ps.component = (ChannelNode *)createNodeWithTag(NED_CHANNEL, ps.inTypes ? (NEDElement *)ps.types : (NEDElement *)ps.nedfile);
                  ((ChannelNode *)ps.component)->setName(toString(@2));
                  //setComments(ps.component,@1,@2);
                }
           opt_inheritance
        | CHANNEL WITHCPPCLASS NAME
                {
                  ps.component = (ChannelNode *)createNodeWithTag(NED_CHANNEL, ps.inTypes ? (NEDElement *)ps.types : (NEDElement *)ps.nedfile);
                  ((ChannelNode *)ps.component)->setName(toString(@3));
                  ((ChannelNode *)ps.component)->setIsWithcppclass(true);
                  //setComments(ps.component,@1,@2);
                }
           opt_inheritance
        ;

opt_inheritance
        :
        | EXTENDS extendsname
        | LIKE likenames
        | EXTENDS extendsname LIKE likenames
        ;

extendsname
        : NAME
                {
                  ps.extends = (ExtendsNode *)createNodeWithTag(NED_EXTENDS, ps.component);
                  ps.extends->setName(toString(@1));
                }
        ;

likenames
        : likenames ',' likename
        | likename
        ;

likename
        : NAME
                {
                  ps.interfacename = (InterfaceNameNode *)createNodeWithTag(NED_INTERFACE_NAME, ps.component);
                  ps.interfacename->setName(toString(@1));
                }
        ;

/*
 * Channel Interface
 */
channelinterfacedefinition
        : channelinterfaceheader '{'
                {
                  ps.typescope.push(ps.component);
                  ps.blockscope.push(ps.component);
                  ps.parameters = (ParametersNode *)createNodeWithTag(NED_PARAMETERS, ps.component);
                  ps.parameters->setIsImplicit(true);
                  ps.propertyscope.push(ps.parameters);
                }
            opt_paramblock
          '}' opt_semicolon
                {
                  ps.propertyscope.pop();
                  ps.blockscope.pop();
                  ps.typescope.pop();
                  setTrailingComment(ps.component,@4);
                  if (np->getStoreSourceFlag())
                      storeComponentSourceCode(ps.component, @$);
                }
        ;

channelinterfaceheader
        : CHANNELINTERFACE NAME
                {
                  ps.component = (ChannelInterfaceNode *)createNodeWithTag(NED_CHANNEL_INTERFACE, ps.inTypes ? (NEDElement *)ps.types : (NEDElement *)ps.nedfile);
                  ((ChannelInterfaceNode *)ps.component)->setName(toString(@2));
                  //setComments(ps.component,@1,@2);
                }
           opt_interfaceinheritance
        ;

opt_interfaceinheritance
        : EXTENDS extendsnames
        |
        ;

extendsnames
        : extendsnames ',' extendsname
        | extendsname
        ;

/*
 * Simple module
 */
simplemoduledefinition
        : simplemoduleheader '{'
                {
                  ps.typescope.push(ps.component);
                  ps.blockscope.push(ps.component);
                  ps.parameters = (ParametersNode *)createNodeWithTag(NED_PARAMETERS, ps.component);
                  ps.parameters->setIsImplicit(true);
                  ps.propertyscope.push(ps.parameters);
                }
            opt_paramblock
            opt_gateblock
          '}' opt_semicolon
                {
                  ps.propertyscope.pop();
                  ps.blockscope.pop();
                  ps.typescope.pop();
                  setTrailingComment(ps.component,@6);
                  if (np->getStoreSourceFlag())
                      storeComponentSourceCode(ps.component, @$);
                }
        ;

simplemoduleheader
        : SIMPLE NAME
                {
                  ps.component = (SimpleModuleNode *)createNodeWithTag(NED_SIMPLE_MODULE, ps.inTypes ? (NEDElement *)ps.types : (NEDElement *)ps.nedfile );
                  ((SimpleModuleNode *)ps.component)->setName(toString(@2));
                  //setComments(ps.component,@1,@2);
                }
          opt_inheritance
        ;

/*
 * Module
 */
compoundmoduledefinition
        : compoundmoduleheader '{'
                {
                  ps.typescope.push(ps.component);
                  ps.blockscope.push(ps.component);
                  ps.parameters = (ParametersNode *)createNodeWithTag(NED_PARAMETERS, ps.component);
                  ps.parameters->setIsImplicit(true);
                  ps.propertyscope.push(ps.parameters);
                }
            opt_paramblock
            opt_gateblock
            opt_typeblock
            opt_submodblock
            opt_connblock
          '}' opt_semicolon
                {
                  ps.propertyscope.pop();
                  ps.blockscope.pop();
                  ps.typescope.pop();
                  setTrailingComment(ps.component,@9);
                  if (np->getStoreSourceFlag())
                      storeComponentSourceCode(ps.component, @$);
                }
        ;

compoundmoduleheader
        : MODULE NAME
                {
                  ps.component = (CompoundModuleNode *)createNodeWithTag(NED_COMPOUND_MODULE, ps.inTypes ? (NEDElement *)ps.types : (NEDElement *)ps.nedfile );
                  ((CompoundModuleNode *)ps.component)->setName(toString(@2));
                  //setComments(ps.component,@1,@2);
                }
          opt_inheritance
        ;

/*
 * Network
 */
networkdefinition
        : networkheader '{'
                {
                  ps.typescope.push(ps.component);
                  ps.blockscope.push(ps.component);
                  ps.parameters = (ParametersNode *)createNodeWithTag(NED_PARAMETERS, ps.component);
                  ps.parameters->setIsImplicit(true);
                  ps.propertyscope.push(ps.parameters);
                }
            opt_paramblock
            opt_gateblock
            opt_typeblock
            opt_submodblock
            opt_connblock
          '}' opt_semicolon
                {
                  ps.propertyscope.pop();
                  ps.blockscope.pop();
                  ps.typescope.pop();
                  setTrailingComment(ps.component,@5);
                  if (np->getStoreSourceFlag())
                      storeComponentSourceCode(ps.component, @$);
                }
        ;

networkheader
        : NETWORK NAME
                {
                  ps.component = (CompoundModuleNode *)createNodeWithTag(NED_COMPOUND_MODULE, ps.inTypes ? (NEDElement *)ps.types : (NEDElement *)ps.nedfile );
                  ((CompoundModuleNode *)ps.component)->setName(toString(@2));
                  ((CompoundModuleNode *)ps.component)->setIsNetwork(true);
                  //setComments(ps.component,@1,@2);
                }
          opt_inheritance
        ;

/*
 * Module Interface
 */
moduleinterfacedefinition
        : moduleinterfaceheader '{'
                {
                  ps.typescope.push(ps.component);
                  ps.blockscope.push(ps.component);
                  ps.parameters = (ParametersNode *)createNodeWithTag(NED_PARAMETERS, ps.component);
                  ps.parameters->setIsImplicit(true);
                  ps.propertyscope.push(ps.parameters);
                }
            opt_paramblock
            opt_gateblock
          '}' opt_semicolon
                {
                  ps.propertyscope.pop();
                  ps.blockscope.pop();
                  ps.typescope.pop();
                  setTrailingComment(ps.component,@6);
                  if (np->getStoreSourceFlag())
                      storeComponentSourceCode(ps.component, @$);
                }
        ;

moduleinterfaceheader
        : INTERFACE NAME
                {
                  ps.component = (ModuleInterfaceNode *)createNodeWithTag(NED_MODULE_INTERFACE, ps.inTypes ? (NEDElement *)ps.types : (NEDElement *)ps.nedfile);
                  ((ModuleInterfaceNode *)ps.component)->setName(toString(@2));
                  //setComments(ps.component,@1,@2);
                }
           opt_interfaceinheritance
        ;

/*
 * Parameters
 */
opt_paramblock
        : opt_params   /* "parameters" keyword is optional */
        | PARAMETERS ':'
                {
                  ps.parameters->setIsImplicit(false);
                }
          opt_params
        ;

opt_params
        : params
        |
        ;

params
        : params paramsitem
                {
                  //setComments(ps.param,@2);
                }
        | paramsitem
                {
                  //setComments(ps.param,@1);
                }
        ;

paramsitem
        : param
        | paramgroup
        | property
        ;

paramgroup
        : opt_condition '{'
                {
                    ps.paramgroup = (ParamGroupNode *)createNodeWithTag(NED_PARAM_GROUP, ps.parameters);
                    if (ps.inGroup)
                       NEDError(ps.paramgroup,"nested parameter groups are not allowed");
                    ps.inGroup = true;
                }
          params '}'
                {
                    ps.inGroup = false;
                    if ($1)
                        ps.paramgroup->appendChild($1); // append optional condition
                }
        ;

param
        : param_typenamevalue
                {
                  ps.propertyscope.push(ps.param);
                }
          opt_inline_properties opt_condition ';'
                {
                  ps.propertyscope.pop();
                  if (ps.inGroup && $4)
                       NEDError(ps.param,"conditional parameters inside parameter/property groups are not allowed");
                  if ($4)
                      ps.param->appendChild($4); // append optional condition
                      // FIXME typename and "if" cannot occur together!!!
                }
        ;

/*
 * Parameter
 */
param_typenamevalue
        : paramtype opt_function NAME
                {
                  ps.param = addParameter(ps.inGroup ? (NEDElement *)ps.paramgroup : (NEDElement *)ps.parameters, @3);
                  ps.param->setType(ps.paramType);
                  ps.param->setIsFunction(ps.isFunction);
                }
        | paramtype opt_function NAME '=' paramvalue
                {
                  ps.param = addParameter(ps.inGroup ? (NEDElement *)ps.paramgroup : (NEDElement *)ps.parameters, @3);
                  ps.param->setType(ps.paramType);
                  ps.param->setIsFunction(ps.isFunction);
                  addExpression(ps.param, "value",@5,$5);
                  ps.param->setIsDefault(ps.isDefault);
                }
        | NAME '=' paramvalue
                {
                  ps.param = addParameter(ps.inGroup ? (NEDElement *)ps.paramgroup : (NEDElement *)ps.parameters, @1);
                  addExpression(ps.param, "value",@3,$3);
                  ps.param->setIsDefault(ps.isDefault);
                }
        | NAME
                {
                  ps.param = addParameter(ps.inGroup ? (NEDElement *)ps.paramgroup : (NEDElement *)ps.parameters, @1);
                }
        | TYPENAME '=' paramvalue  /* this is to assign module type with the "<> like Foo" syntax */
                {
                  ps.param = addParameter(ps.inGroup ? (NEDElement *)ps.paramgroup : (NEDElement *)ps.parameters, @1);
                  addExpression(ps.param, "value",@3,$3);
                  ps.param->setIsDefault(ps.isDefault);
                }
        | '/' pattern '/' '=' paramvalue
                {
                  ps.pattern = (PatternNode *)createNodeWithTag(NED_PATTERN, ps.inGroup ? (NEDElement *)ps.paramgroup : (NEDElement *)ps.parameters);
                  ps.pattern->setPattern(toString(@2));
                  addExpression(ps.pattern, "value",@5,$5);
                  ps.pattern->setIsDefault(ps.isDefault);
                }

paramtype
        : DOUBLETYPE
                { ps.paramType = NED_PARTYPE_DOUBLE; }
        | INTTYPE
                { ps.paramType = NED_PARTYPE_INT; }
        | STRINGTYPE
                { ps.paramType = NED_PARTYPE_STRING; }
        | BOOLTYPE
                { ps.paramType = NED_PARTYPE_BOOL; }
        | XMLTYPE
                { ps.paramType = NED_PARTYPE_XML; }
        ;

opt_function
        : FUNCTION
                { ps.isFunction = true; }
        |
                { ps.isFunction = false; }
        ;

paramvalue
        : expression
                { $$ = $1; ps.isDefault = false; }
        | DEFAULT '(' expression ')'
                { $$ = $3; ps.isDefault = true; }
        ;

opt_inline_properties
        : inline_properties
        |
        ;

inline_properties
        : inline_properties property_namevalue
        | property_namevalue
        ;

pattern /* this attempts to capture inifile-like patterns */
        : pattern pattern_elem
        | pattern_elem
        ;

pattern_elem
        : '.'
        | '*'
        | '?'
        | DOUBLEASTERISK
        | NAME
        | INTCONSTANT
        | TO
        | '[' pattern ']'
        | '{' pattern '}'
        /* allow reserved words in patterns as well */
        | IMPORT | PACKAGE | PROPERTY
        | MODULE | SIMPLE | NETWORK | CHANNEL | INTERFACE | CHANNELINTERFACE
        | EXTENDS | LIKE | WITHCPPCLASS
        | DOUBLETYPE | INTTYPE | STRINGTYPE | BOOLTYPE | XMLTYPE | FUNCTION | TYPENAME
        | INPUT_ | OUTPUT_ | INOUT_ | IF | WHERE
        | TYPES | PARAMETERS | GATES | SUBMODULES | CONNECTIONS | ALLOWUNCONNECTED
        | TRUE_ | FALSE_ | THIS_ | DEFAULT | CONST_ | SIZEOF | INDEX_ | XMLDOC
        ;

/*
 * Property
 */
property
        : property_namevalue opt_condition ';'
                {
                  if (ps.inGroup && $2)
                       NEDError(ps.param,"conditional properties inside parameter/property groups are not allowed");
                  if ($2)
                      ps.property->appendChild($2); // append optional condition
                }
        ;

property_namevalue
        : property_name
        | property_name '(' opt_property_keys ')'
        ;

property_name
        : '@' NAME
                {
                  ps.property = addProperty(ps.propertyscope.top(), toString(@2));
                }
        ;

opt_property_keys
        : property_keys
        |
        ;

property_keys
        : property_keys ',' property_key
        | property_key
        ;

property_key
        : NAME '=' property_value
                {
                  ps.propkey = (PropertyKeyNode *)createNodeWithTag(NED_PROPERTY_KEY, ps.property);
                  ps.propkey->setKey(toString(@1));
                  ps.propkey->appendChild($3);
                }
        | property_value
                {
                  ps.propkey = (PropertyKeyNode *)createNodeWithTag(NED_PROPERTY_KEY, ps.property);
                  ps.propkey->appendChild($1);
                }
        ;

property_value
        : NAME
                { $$ = createLiteral(NED_CONST_STRING, @1, @1); }
        | STRINGCONSTANT
                { $$ = createLiteral(NED_CONST_STRING, trimQuotes(@1), @1); }
        | TRUE_
                { $$ = createLiteral(NED_CONST_BOOL, @1, @1); }
        | FALSE_
                { $$ = createLiteral(NED_CONST_BOOL, @1, @1); }
        | INTCONSTANT
                { $$ = createLiteral(NED_CONST_INT, @1, @1); }
        | REALCONSTANT
                { $$ = createLiteral(NED_CONST_DOUBLE, @1, @1); }
        | quantity
                { $$ = createQuantity(toString(@1)); }
        ;

/*
 * Gates
 */
opt_gateblock
        : gateblock
        |
        ;

gateblock
        : GATES ':'
                {
                  ps.gates = (GatesNode *)createNodeWithTag(NED_GATES, ps.blockscope.top());
                  //setComments(ps.gates,@1,@2);
                }
          opt_gates
                {
                }
        ;

opt_gates
        : gates
        |
        ;

gates
        : gates gatesitem
                {
                  //setComments(ps.gate,@2);
                }
        | gatesitem
                {
                  //setComments(ps.gate,@1);
                }
        ;

gatesitem
        : gategroup
        | gate
        ;

gategroup
        : opt_condition '{'
                {
                    ps.gategroup = (GateGroupNode *)createNodeWithTag(NED_GATE_GROUP, ps.gates);
                    if (ps.inGroup)
                       NEDError(ps.gategroup,"nested gate groups are not allowed");
                    ps.inGroup = true;
                }
          gates '}'
                {
                    ps.inGroup = false;
                    if ($1)
                        ps.gategroup->appendChild($1); // append optional condition
                }
        ;

/*
 * Gate
 */
gate
        : gate_typenamesize
                {
                  ps.propertyscope.push(ps.gate);
                }
          opt_inline_properties opt_condition ';'
                {
                  ps.propertyscope.pop();
                  if (ps.inGroup && $4)
                       NEDError(ps.param,"conditional gates inside gate groups are not allowed");
                  if ($4)
                      ps.gate->appendChild($4); // append optional condition
                      // FIXME typename and "if" cannot occur together!!!
                }
        ;

gate_typenamesize
        : gatetype NAME
                {
                  ps.gate = addGate(ps.inGroup ? (NEDElement *)ps.gategroup : (NEDElement *)ps.gates, @2);
                  ps.gate->setType(ps.gateType);
                }
        | gatetype NAME '[' ']'
                {
                  ps.gate = addGate(ps.inGroup ? (NEDElement *)ps.gategroup : (NEDElement *)ps.gates, @2);
                  ps.gate->setType(ps.gateType);
                  ps.gate->setIsVector(true);
                }
        | gatetype NAME vector
                {
                  ps.gate = addGate(ps.inGroup ? (NEDElement *)ps.gategroup : (NEDElement *)ps.gates, @2);
                  ps.gate->setType(ps.gateType);
                  addVector(ps.gate, "vector-size",@3,$3);
                }
        | NAME
                {
                  ps.gate = addGate(ps.inGroup ? (NEDElement *)ps.gategroup : (NEDElement *)ps.gates, @1);
                }
        | NAME '[' ']'
                {
                  ps.gate = addGate(ps.inGroup ? (NEDElement *)ps.gategroup : (NEDElement *)ps.gates, @1);
                  ps.gate->setIsVector(true);
                }
        | NAME vector
                {
                  ps.gate = addGate(ps.inGroup ? (NEDElement *)ps.gategroup : (NEDElement *)ps.gates, @1);
                  addVector(ps.gate, "vector-size",@2,$2);
                }
        ;

gatetype
        : INPUT_
                { ps.gateType = NED_GATETYPE_INPUT; }
        | OUTPUT_
                { ps.gateType = NED_GATETYPE_OUTPUT; }
        | INOUT_
                { ps.gateType = NED_GATETYPE_INOUT; }
        ;

/*
 * Local Types
 */
opt_typeblock
        : typeblock
        |
        ;

typeblock
        : TYPES ':'
                {
                  ps.types = (TypesNode *)createNodeWithTag(NED_TYPES, ps.blockscope.top());
                  //setComments(ps.types,@1,@2);
                  if (ps.inTypes)
                     NEDError(ps.paramgroup,"more than one level of type nesting is not allowed");
                  ps.inTypes = true;
                }
           opt_localtypes
                {
                  ps.inTypes = false;
                }
        ;

opt_localtypes
        : localtypes
        |
        ;

localtypes
        : localtypes localtype
        | localtype
        ;

localtype
        : propertydecl
        | channeldefinition
        | channelinterfacedefinition
        | simplemoduledefinition
        | compoundmoduledefinition
        | networkdefinition
        | moduleinterfacedefinition
        ;

/*
 * Submodules
 */
opt_submodblock
        : submodblock
        |
        ;

submodblock
        : SUBMODULES ':'
                {
                  ps.submods = (SubmodulesNode *)createNodeWithTag(NED_SUBMODULES, ps.blockscope.top());
                  //setComments(ps.submods,@1,@2);
                }
          opt_submodules
                {
                }
        ;

opt_submodules
        : submodules
        |
        ;

submodules
        : submodules submodule
        | submodule
        ;

submodule
        : submoduleheader ';'
                {
                  //setComments(ps.submod,@1,@2);
                }
        | submoduleheader '{'
                {
                  ps.blockscope.push(ps.submod);
                  ps.parameters = (ParametersNode *)createNodeWithTag(NED_PARAMETERS, ps.submod);
                  ps.parameters->setIsImplicit(true);
                  ps.propertyscope.push(ps.parameters);
                  //setComments(ps.submod,@1,@2);
                }
          opt_paramblock
          opt_gateblock
          '}' opt_semicolon
                {
                  ps.blockscope.pop();
                  ps.propertyscope.pop();
                }
        ;

submoduleheader
        : submodulename ':' NAME
                {
                  ps.submod->setType(toString(@3));
                }
        | submodulename ':' likeparam LIKE NAME
                {
                  addLikeParam(ps.submod, "like-param", @3, $3);
                  ps.submod->setLikeType(toString(@5));
                }
        | submodulename ':' likeparam LIKE '*'
                {
                  addLikeParam(ps.submod, "like-param", @3, $3);
                  ps.submod->setLikeAny(true);
                }
        ;

submodulename
        : NAME
                {
                  ps.submod = (SubmoduleNode *)createNodeWithTag(NED_SUBMODULE, ps.submods);
                  ps.submod->setName(toString(@1));
                }
        |  NAME vector
                {
                  ps.submod = (SubmoduleNode *)createNodeWithTag(NED_SUBMODULE, ps.submods);
                  ps.submod->setName(toString(@1));
                  addVector(ps.submod, "vector-size",@2,$2);
                }
        ;

likeparam
        : '<' '>'
                { $$ = NULL; }
        | '<' '@' NAME '>'
                { $$ = NULL; }
        | '<' qualifier '.' '@' NAME '>' /* note: qualifier here must be "this" */
                {
                  if (strcmp(toString(@2),"this")!=0)
                       NEDError(NULL,"invalid property qualifier `%s', only `this' is allowed here", toString(@2));
                  $$ = NULL;
                }
        | '<' expression '>' /* XXX this expression is the source of one shift-reduce conflict because it may contain '>' */
                { $$ = $2; }
        ;

/*
 * Connections
 */
opt_connblock
        : connblock
        |
        ;

connblock
        : CONNECTIONS ALLOWUNCONNECTED ':'
                {
                  ps.conns = (ConnectionsNode *)createNodeWithTag(NED_CONNECTIONS, ps.blockscope.top());
                  ps.conns->setAllowUnconnected(true);
                  //setComments(ps.conns,@1,@3);
                }
          opt_connections
                {
                }
        | CONNECTIONS ':'
                {
                  ps.conns = (ConnectionsNode *)createNodeWithTag(NED_CONNECTIONS, ps.blockscope.top());
                  //setComments(ps.conns,@1,@2);
                }
          opt_connections
                {
                }
        ;

opt_connections
        : connections
        |
        ;

connections
        : connections connectionsitem
        | connectionsitem
        ;

connectionsitem
        : connectiongroup
        | connection opt_whereclause ';'
                {
                  if (ps.inGroup && $2)
                       NEDError(ps.param,"conditional connections inside connection groups are not allowed");
                  if ($2)
                      ps.conn->appendChild($2);
                }
        ;

connectiongroup  /* note: semicolon at end is mandatory (cannot be opt_semicolon because it'd be ambiguous where "where" clause in "{a-->b;} where i>0 {c-->d;}" belongs) */
        : whereclause '{'
                {
                  ps.conngroup = (ConnectionGroupNode *)createNodeWithTag(NED_CONNECTION_GROUP, ps.conns);
                  if (ps.inGroup)
                     NEDError(ps.conngroup,"nested connection groups are not allowed");
                  ps.inGroup = true;
                }
          connections '}' ';'
                {
                  ps.inGroup = false;
                  ps.conngroup->appendChild(ps.where);  // XXX appendChild($1) crashes, $1 being NULL (???)
                  ps.where->setAtFront(true);
                }
        | '{'
                {
                  ps.conngroup = (ConnectionGroupNode *)createNodeWithTag(NED_CONNECTION_GROUP, ps.conns);
                  if (ps.inGroup)
                     NEDError(ps.conngroup,"nested connection groups are not allowed");
                  ps.inGroup = true;
                }
          connections '}' opt_whereclause ';'
                {
                  ps.inGroup = false;
                  if ($5)
                      ps.conngroup->appendChild($5);
                }
        ;

opt_whereclause
        : whereclause
            { $$ = ps.where; }
        |
            { $$ = NULL; }
        ;

whereclause
        : WHERE
                {
                  ps.where = (WhereNode *)createNodeWithTag(NED_WHERE);
                  ps.where->setAtFront(false); // by default
                }
          whereitems
        ;

whereitems
        : whereitems ',' whereitem
        | whereitem
        ;

whereitem
        : expression   /* that is, a condition */
                {
                  ps.condition = (ConditionNode *)createNodeWithTag(NED_CONDITION, ps.where);
                  addExpression(ps.condition, "condition",@1,$1);
                }
        | loop
        ;

loop
        : NAME '=' expression TO expression
                {
                  ps.loop = addLoop(ps.where, @1);
                  addExpression(ps.loop, "from-value",@3,$3);
                  addExpression(ps.loop, "to-value",@5,$5);
                  //setComments(ps.loop,@1,@5);
                }
        ;

/*
 * Connection
 */
connection
        : leftgatespec RIGHTARROW rightgatespec
                {
                  ps.conn->setArrowDirection(NED_ARROWDIR_L2R);
                  //setComments(ps.conn,@1,@3);
                }
        | leftgatespec RIGHTARROW channelspec RIGHTARROW rightgatespec
                {
                  ps.conn->setArrowDirection(NED_ARROWDIR_L2R);
                  //setComments(ps.conn,@1,@5);
                }
        | leftgatespec LEFTARROW rightgatespec
                {
                  swapConnection(ps.conn);
                  ps.conn->setArrowDirection(NED_ARROWDIR_R2L);
                  //setComments(ps.conn,@1,@3);
                }
        | leftgatespec LEFTARROW channelspec LEFTARROW rightgatespec
                {
                  swapConnection(ps.conn);
                  ps.conn->setArrowDirection(NED_ARROWDIR_R2L);
                  //setComments(ps.conn,@1,@5);
                }
        | leftgatespec DBLARROW rightgatespec
                {
                  ps.conn->setArrowDirection(NED_ARROWDIR_BIDIR);
                  //setComments(ps.conn,@1,@3);
                }
        | leftgatespec DBLARROW channelspec DBLARROW rightgatespec
                {
                  ps.conn->setArrowDirection(NED_ARROWDIR_BIDIR);
                  //setComments(ps.conn,@1,@5);
                }
        ;

leftgatespec
        : leftmod '.' leftgate opt_subgate
                { ps.conn->setSrcGateSubg(ps.subgate); }
        | parentleftgate opt_subgate
                { ps.conn->setSrcGateSubg(ps.subgate); }
        ;

leftmod
        : NAME vector
                {
                  ps.conn = (ConnectionNode *)createNodeWithTag(NED_CONNECTION, ps.inGroup ? (NEDElement*)ps.conngroup : (NEDElement*)ps.conns );
                  ps.conn->setSrcModule( toString(@1) );
                  addVector(ps.conn, "src-module-index",@2,$2);
                }
        | NAME
                {
                  ps.conn = (ConnectionNode *)createNodeWithTag(NED_CONNECTION, ps.inGroup ? (NEDElement*)ps.conngroup : (NEDElement*)ps.conns );
                  ps.conn->setSrcModule( toString(@1) );
                }
        ;

leftgate
        : NAME
                {
                  ps.conn->setSrcGate( toString( @1) );
                }
        | NAME vector
                {
                  ps.conn->setSrcGate( toString( @1) );
                  addVector(ps.conn, "src-gate-index",@2,$2);
                }
        | NAME PLUSPLUS
                {
                  ps.conn->setSrcGate( toString( @1) );
                  ps.conn->setSrcGatePlusplus(true);
                }
        ;

parentleftgate
        : NAME
                {
                  ps.conn = (ConnectionNode *)createNodeWithTag(NED_CONNECTION, ps.inGroup ? (NEDElement*)ps.conngroup : (NEDElement*)ps.conns );
                  ps.conn->setSrcModule("");
                  ps.conn->setSrcGate(toString(@1));
                }
        | NAME vector
                {
                  ps.conn = (ConnectionNode *)createNodeWithTag(NED_CONNECTION, ps.inGroup ? (NEDElement*)ps.conngroup : (NEDElement*)ps.conns );
                  ps.conn->setSrcModule("");
                  ps.conn->setSrcGate(toString(@1));
                  addVector(ps.conn, "src-gate-index",@2,$2);
                }
        | NAME PLUSPLUS
                {
                  ps.conn = (ConnectionNode *)createNodeWithTag(NED_CONNECTION, ps.inGroup ? (NEDElement*)ps.conngroup : (NEDElement*)ps.conns );
                  ps.conn->setSrcModule("");
                  ps.conn->setSrcGate(toString(@1));
                  ps.conn->setSrcGatePlusplus(true);
                }
        ;

rightgatespec
        : rightmod '.' rightgate opt_subgate
                { ps.conn->setDestGateSubg(ps.subgate); }
        | parentrightgate opt_subgate
                { ps.conn->setDestGateSubg(ps.subgate); }
        ;

rightmod
        : NAME
                {
                  ps.conn->setDestModule( toString(@1) );
                }
        | NAME vector
                {
                  ps.conn->setDestModule( toString(@1) );
                  addVector(ps.conn, "dest-module-index",@2,$2);
                }
        ;

rightgate
        : NAME
                {
                  ps.conn->setDestGate( toString( @1) );
                }
        | NAME vector
                {
                  ps.conn->setDestGate( toString( @1) );
                  addVector(ps.conn, "dest-gate-index",@2,$2);
                }
        | NAME PLUSPLUS
                {
                  ps.conn->setDestGate( toString( @1) );
                  ps.conn->setDestGatePlusplus(true);
                }
        ;

parentrightgate
        : NAME
                {
                  ps.conn->setDestGate( toString( @1) );
                }
        | NAME vector
                {
                  ps.conn->setDestGate( toString( @1) );
                  addVector(ps.conn, "dest-gate-index",@2,$2);
                }
        | NAME PLUSPLUS
                {
                  ps.conn->setDestGate( toString( @1) );
                  ps.conn->setDestGatePlusplus(true);
                }
        ;

opt_subgate
        : '$' NAME
                {
                  const char *s = toString(@2);
                  if (!strcmp(s,"i"))
                      ps.subgate = NED_SUBGATE_I;
                  else if (!strcmp(s,"o"))
                      ps.subgate = NED_SUBGATE_O;
                  else
                       NEDError(NULL,"invalid subgate spec `%s', must be `i' or `o'", toString(@2));
                }
        |
                {  ps.subgate = NED_SUBGATE_NONE; }
        ;

channelspec
        : channelspec_header
        | channelspec_header '{'
                {
                  ps.parameters = (ParametersNode *)createNodeWithTag(NED_PARAMETERS, ps.chanspec);
                  ps.parameters->setIsImplicit(true);
                  ps.propertyscope.push(ps.parameters);
                }
            opt_paramblock
          '}'
                {
                  ps.propertyscope.pop();
                  ps.blockscope.pop();
                }
        ;


channelspec_header
        :
                {
                  ps.chanspec = (ChannelSpecNode *)createNodeWithTag(NED_CHANNEL_SPEC, ps.conn);
                }
        | NAME
                {
                  ps.chanspec = (ChannelSpecNode *)createNodeWithTag(NED_CHANNEL_SPEC, ps.conn);
                  ps.chanspec->setType(toString(@1));
                }
        | likeparam LIKE NAME
                {
                  ps.chanspec = (ChannelSpecNode *)createNodeWithTag(NED_CHANNEL_SPEC, ps.conn);
                  addLikeParam(ps.chanspec, "like-param", @1, $1);
                  ps.chanspec->setLikeType(toString(@3));
                }
        | likeparam LIKE '*'
                {
                  ps.chanspec = (ChannelSpecNode *)createNodeWithTag(NED_CHANNEL_SPEC, ps.conn);
                  addLikeParam(ps.chanspec, "like-param", @1, $1);
                  ps.chanspec->setLikeAny(true);
                }
        ;

/*
 * Condition
 */
opt_condition
        : condition
           { $$ = $1; }
        |
           { $$ = NULL; }
        ;

condition
        : IF expression
                {
                  ps.condition = (ConditionNode *)createNodeWithTag(NED_CONDITION);
                  addExpression(ps.condition, "condition",@2,$2);
                  $$ = ps.condition;
                }
        ;

/*
 * Common part
 */
vector
        : '[' expression ']'
                { $$ = $2; }
        ;

expression
        :
          expr
                {
                  if (np->getParseExpressionsFlag()) $$ = createExpression($1);
                }
        | xmldocvalue
                {
                  if (np->getParseExpressionsFlag()) $$ = createExpression($1);
                }
        ;

/*
 * Expressions
 */
xmldocvalue
        : XMLDOC '(' stringliteral ',' stringliteral ')'
                { if (np->getParseExpressionsFlag()) $$ = createFunction("xmldoc", $3, $5); }
        | XMLDOC '(' stringliteral ')'
                { if (np->getParseExpressionsFlag()) $$ = createFunction("xmldoc", $3); }
        ;

expr
        : simple_expr
        | '(' expr ')'
                { $$ = $2; }
        | CONST_ '(' expr ')'
                { $$ = $3; /*FIXME*/ }

        | expr '+' expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("+", $1, $3); }
        | expr '-' expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("-", $1, $3); }
        | expr '*' expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("*", $1, $3); }
        | expr '/' expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("/", $1, $3); }
        | expr '%' expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("%", $1, $3); }
        | expr '^' expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("^", $1, $3); }

        | '-' expr
                %prec UMIN
                { if (np->getParseExpressionsFlag()) $$ = unaryMinus($2); }

        | expr EQ expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("==", $1, $3); }
        | expr NE expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("!=", $1, $3); }
        | expr '>' expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator(">", $1, $3); }
        | expr GE expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator(">=", $1, $3); }
        | expr '<' expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("<", $1, $3); }
        | expr LE expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("<=", $1, $3); }

        | expr AND expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("&&", $1, $3); }
        | expr OR expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("||", $1, $3); }
        | expr XOR expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("##", $1, $3); }

        | NOT expr
                %prec UMIN
                { if (np->getParseExpressionsFlag()) $$ = createOperator("!", $2); }

        | expr BIN_AND expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("&", $1, $3); }
        | expr BIN_OR expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("|", $1, $3); }
        | expr BIN_XOR expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("#", $1, $3); }

        | BIN_COMPL expr
                %prec UMIN
                { if (np->getParseExpressionsFlag()) $$ = createOperator("~", $2); }
        | expr SHIFT_LEFT expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("<<", $1, $3); }
        | expr SHIFT_RIGHT expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator(">>", $1, $3); }
        | expr '?' expr ':' expr
                { if (np->getParseExpressionsFlag()) $$ = createOperator("?:", $1, $3, $5); }

        | NAME '(' ')'
                { if (np->getParseExpressionsFlag()) $$ = createFunction(toString(@1)); }
        | NAME '(' expr ')'
                { if (np->getParseExpressionsFlag()) $$ = createFunction(toString(@1), $3); }
        | NAME '(' expr ',' expr ')'
                { if (np->getParseExpressionsFlag()) $$ = createFunction(toString(@1), $3, $5); }
        | NAME '(' expr ',' expr ',' expr ')'
                { if (np->getParseExpressionsFlag()) $$ = createFunction(toString(@1), $3, $5, $7); }
        | NAME '(' expr ',' expr ',' expr ',' expr ')'
                { if (np->getParseExpressionsFlag()) $$ = createFunction(toString(@1), $3, $5, $7, $9); }
         ;

simple_expr
        : parameter_expr
        | special_expr
        | literal
        ;

parameter_expr
        : NAME
                {
                  // if there's no modifier, might be a loop variable too
                  if (np->getParseExpressionsFlag()) $$ = createIdent(toString(@1));
                }
        | qualifier '.' NAME
                {
                  // if there's no modifier, might be a loop variable too
                  if (np->getParseExpressionsFlag()) $$ = createIdent(toString(@1));
                }
        ;

qualifier
        : THIS_
        | NAME  /* submodule name */
        | NAME vector
        ;

special_expr
        : INDEX_
                { if (np->getParseExpressionsFlag()) $$ = createFunction("index"); }
        | INDEX_ '(' ')'
                { if (np->getParseExpressionsFlag()) $$ = createFunction("index"); }
        | SIZEOF '(' NAME ')'
                { if (np->getParseExpressionsFlag()) $$ = createFunction("sizeof", createIdent(toString(@3))); }
        | SIZEOF '(' NAME '.' NAME ')'
                { if (np->getParseExpressionsFlag()) $$ = createFunction("sizeof", createIdent(toString(@5), NULL, toString(@3))); }
        ;

literal
        : stringliteral
        | boolliteral
        | numliteral
        ;

stringliteral
        : STRINGCONSTANT
                { if (np->getParseExpressionsFlag()) $$ = createLiteral(NED_CONST_STRING, trimQuotes(@1), @1); }
        ;

boolliteral
        : TRUE_
                { if (np->getParseExpressionsFlag()) $$ = createLiteral(NED_CONST_BOOL, @1, @1); }
        | FALSE_
                { if (np->getParseExpressionsFlag()) $$ = createLiteral(NED_CONST_BOOL, @1, @1); }
        ;

numliteral
        : INTCONSTANT
                { if (np->getParseExpressionsFlag()) $$ = createLiteral(NED_CONST_INT, @1, @1); }
        | REALCONSTANT
                { if (np->getParseExpressionsFlag()) $$ = createLiteral(NED_CONST_DOUBLE, @1, @1); }
        | quantity
                { if (np->getParseExpressionsFlag()) $$ = createQuantity(toString(@1)); }
        ;

quantity
        : quantity INTCONSTANT NAME
        | quantity REALCONSTANT NAME
        | INTCONSTANT NAME
        | REALCONSTANT NAME
        ;

opt_semicolon : ';' | ;

%%

//----------------------------------------------------------------------
// general bison/flex stuff:
//

NEDElement *doParseNED2(NEDParser *p, const char *nedtext)
{
#if YYDEBUG != 0      /* #if added --VA */
    yydebug = YYDEBUGGING_ON;
#endif

    // reset the lexer
    pos.co = 0;
    pos.li = 1;
    prevpos = pos;

    yyin = NULL;
    yyout = stderr; // not used anyway

    // alloc buffer
    struct yy_buffer_state *handle = yy_scan_string(nedtext);
    if (!handle)
        {NEDError(NULL, "unable to allocate work memory"); return false;}

    // create parser state and NEDFileNode
    np = p;
    resetParserState();
    ps.nedfile = new NedFileNode();

    // store file name with slashes always, even on Windows -- neddoc relies on that
    ps.nedfile->setFilename(slashifyFilename(np->getFileName()).c_str());

    // store file comment
    //FIXME ps.nedfile->setBannerComment(nedsource->getFileComment());

    ps.propertyscope.push(ps.nedfile);

    if (np->getStoreSourceFlag())
        storeSourceCode(ps.nedfile, np->nedsource->getFullTextPos());

    // parse
    int ret;
    try
    {
        ret = yyparse();
    }
    catch (NEDException *e)
    {
        INTERNAL_ERROR1(NULL, "error during parsing: %s", e->errorMessage());
        yy_delete_buffer(handle);
        delete e;
        return 0;
    }

    if (!errorsOccurred())
    {
        // more sanity checks
        if (ps.propertyscope.size()!=1 || ps.propertyscope.top()!=ps.nedfile)
            INTERNAL_ERROR0(NULL, "error during parsing: imbalanced propertyscope");
        if (!ps.blockscope.empty() || !ps.typescope.empty())
            INTERNAL_ERROR0(NULL, "error during parsing: imbalanced blockscope or typescope");
    }
    yy_delete_buffer(handle);
    return ps.nedfile;
}

void yyerror(const char *s)
{
    // chop newline
    char buf[250];
    strcpy(buf, s);
    if (buf[strlen(buf)-1] == '\n')
        buf[strlen(buf)-1] = '\0';

    np->error(buf, pos.li);
}

