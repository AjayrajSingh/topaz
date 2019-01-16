// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package ir

import (
	"fidl/compiler/backend/common"
	"fidl/compiler/backend/types"
	"fmt"
	"log"
	"regexp"
	"strconv"
	"strings"
)

// Documented is embedded in structs for declarations that may hold documentation.
type Documented struct {
	Doc []string
}

// Type represents a FIDL datatype.
type Type struct {
	Decl          string // type in traditional bindings
	SyncDecl      string // type in async bindings when referring to traditional bindings
	AsyncDecl     string // type in async bindings when referring to async bindings
	Nullable      bool
	declType      types.DeclType
	typedDataDecl string
	typeExpr      string
}

// Const represents a constant declaration.
type Const struct {
	Type  Type
	Name  string
	Value string
	Documented
}

// Enum represents an enum declaration.
type Enum struct {
	Name       string
	Members    []EnumMember
	TypeSymbol string
	TypeExpr   string
	Documented
}

// EnumMember represents a member of an enum declaration.
type EnumMember struct {
	Name  string
	Value string
	Documented
}

// Union represents a union declaration.
type Union struct {
	Name       string
	TagName    string
	Members    []UnionMember
	TypeSymbol string
	TypeExpr   string
	Documented
}

// UnionMember represents a member of a union declaration.
type UnionMember struct {
	Type     Type
	Name     string
	CtorName string
	Offset   int
	typeExpr string
	Documented
}

// Struct represents a struct declaration.
type Struct struct {
	Name             string
	Members          []StructMember
	TypeSymbol       string
	TypeExpr         string
	HasNullableField bool
	Documented
}

// StructMember represents a member of a struct declaration.
type StructMember struct {
	Type         Type
	Name         string
	DefaultValue string
	Offset       int
	typeExpr     string
	Documented
}

// Table represents a table declaration.
type Table struct {
	Name       string
	Members    []TableMember
	TypeSymbol string
	TypeExpr   string
	Documented
}

// TableMember represents a member of a table declaration.
type TableMember struct {
	Ordinal      int
	Type         Type
	Name         string
	DefaultValue string
	typeExpr     string
	Documented
}

// Interface represents an interface declaration.
type Interface struct {
	Name        string
	ServiceName string
	ServiceData string
	ProxyName   string
	BindingName string
	EventsName  string
	Methods     []Method
	HasEvents   bool
	Documented
}

// Method represents a method declaration within an interface declaration.
type Method struct {
	Ordinal            types.Ordinal
	OrdinalName        string
	Name               string
	HasRequest         bool
	Request            []Parameter
	RequestSize        int
	HasResponse        bool
	Response           []Parameter
	ResponseSize       int
	AsyncResponseClass string
	AsyncResponseType  string
	CallbackType       string
	TypeSymbol         string
	TypeExpr           string
	Transitional       bool
	Documented
}

// Parameter represents an interface method parameter.
type Parameter struct {
	Type     Type
	Name     string
	Offset   int
	Convert  string
	typeExpr string
}

// Import describes another FIDL library that will be imported.
type Import struct {
	URL       string
	LocalName string
	AsyncURL  string
}

// Root holds all of the declarations for a FIDL library.
type Root struct {
	LibraryName string
	Imports     []Import
	Consts      []Const
	Enums       []Enum
	Interfaces  []Interface
	Structs     []Struct
	Tables      []Table
	Unions      []Union
}

// FIXME(FIDL-107): Add "get" and "set" back to this list.
// They are only reserved in certain contexts.  We should add them
// back but also make the code generator smarter about escaping
// reserved words to avoid style violations in various contexts.
var reservedWords = map[string]bool{
	// "Error":      true,
	"abstract":   true,
	"as":         true,
	"assert":     true,
	"async":      true,
	"await":      true,
	"break":      true,
	"bool":       true,
	"case":       true,
	"catch":      true,
	"class":      true,
	"const":      true,
	"continue":   true,
	"covariant":  true,
	"default":    true,
	"deferred":   true,
	"do":         true,
	"double":     true,
	"dynamic":    true,
	"else":       true,
	"enum":       true,
	"export":     true,
	"extends":    true,
	"external":   true,
	"factory":    true,
	"false":      true,
	"final":      true,
	"finally":    true,
	"for":        true,
	"if":         true,
	"implements": true,
	"import":     true,
	"in":         true,
	"int":        true,
	"is":         true,
	"library":    true,
	"new":        true,
	"null":       true,
	"num":        true,
	"Object":     true,
	"operator":   true,
	"part":       true,
	"rethrow":    true,
	"return":     true,
	"static":     true,
	"String":     true,
	"super":      true,
	"switch":     true,
	"this":       true,
	"throw":      true,
	"true":       true,
	"try":        true,
	"typedef":    true,
	"var":        true,
	"void":       true,
	"while":      true,
	"with":       true,
	"yield":      true,
}

var declForPrimitiveType = map[types.PrimitiveSubtype]string{
	types.Bool:    "bool",
	types.Int8:    "int",
	types.Int16:   "int",
	types.Int32:   "int",
	types.Int64:   "int",
	types.Uint8:   "int",
	types.Uint16:  "int",
	types.Uint32:  "int",
	types.Uint64:  "int",
	types.Float32: "double",
	types.Float64: "double",
}

var typedDataDecl = map[types.PrimitiveSubtype]string{
	types.Int8:    "Int8List",
	types.Int16:   "Int16List",
	types.Int32:   "Int32List",
	types.Int64:   "Int64List",
	types.Uint8:   "Uint8List",
	types.Uint16:  "Uint16List",
	types.Uint32:  "Uint32List",
	types.Uint64:  "Uint64List",
	types.Float32: "Float32List",
	types.Float64: "Float64List",
}

var typeForPrimitiveSubtype = map[types.PrimitiveSubtype]string{
	types.Bool:    "BoolType",
	types.Int8:    "Int8Type",
	types.Int16:   "Int16Type",
	types.Int32:   "Int32Type",
	types.Int64:   "Int64Type",
	types.Uint8:   "Uint8Type",
	types.Uint16:  "Uint16Type",
	types.Uint32:  "Uint32Type",
	types.Uint64:  "Uint64Type",
	types.Float32: "Float32Type",
	types.Float64: "Float64Type",
}

func docStringLink(nameWithBars string) string {
	return fmt.Sprintf("[%s]", nameWithBars[1:len(nameWithBars)-1])
}

var reLink = regexp.MustCompile("\\|([^\\|]+)\\|")

// TODO(pascallouis): rethink how we depend on the types package.
type Annotated interface {
	LookupAttribute(types.Identifier) (types.Attribute, bool)
}

func docString(node Annotated) Documented {
	attribute, ok := node.LookupAttribute("Doc")
	if !ok {
		return Documented{nil}
	}
	var docs []string
	lines := strings.Split(attribute.Value, "\n")
	if len(lines[len(lines)-1]) == 0 {
		// Remove the blank line at the end
		lines = lines[:len(lines)-1]
	}
	for _, line := range lines {
		// Turn |something| into [something]
		line = reLink.ReplaceAllStringFunc(line, docStringLink)
		docs = append(docs, line)
	}
	return Documented{docs}
}

func formatBool(val bool) string {
	return strconv.FormatBool(val)
}

func formatInt(val *int) string {
	if val == nil {
		return "null"
	}
	return strconv.Itoa(*val)
}

func formatParameterList(params []Parameter) string {
	if len(params) == 0 {
		return "null"
	}

	lines := []string{}

	for _, p := range params {
		lines = append(lines, fmt.Sprintf("      %s,\n", p.typeExpr))
	}

	return fmt.Sprintf("const <$fidl.MemberType>[\n%s    ]", strings.Join(lines, ""))
}

func formatStructMemberList(members []StructMember) string {
	if len(members) == 0 {
		return "const <$fidl.MemberType>[]"
	}

	lines := []string{}

	for _, v := range members {
		lines = append(lines, fmt.Sprintf("    %s,\n", v.typeExpr))
	}

	return fmt.Sprintf("const <$fidl.MemberType>[\n%s  ]", strings.Join(lines, ""))
}

func formatTableMemberList(members []TableMember) string {
	if len(members) == 0 {
		return "const <int, $fidl.FidlType>{}"
	}

	lines := []string{}

	for _, v := range members {
		lines = append(lines, fmt.Sprintf("    %d: %s,\n", v.Ordinal, v.Type.typeExpr))
	}

	return fmt.Sprintf("const <int, $fidl.FidlType>{\n%s  }", strings.Join(lines, ""))
}

func formatUnionMemberList(members []UnionMember) string {
	if len(members) == 0 {
		return "const <$fidl.MemberType>[]"
	}

	lines := []string{}

	for _, v := range members {
		lines = append(lines, fmt.Sprintf("    %s,\n", v.typeExpr))
	}

	return fmt.Sprintf("const <$fidl.MemberType>[\n%s  ]", strings.Join(lines, ""))
}

func formatLibraryName(library types.LibraryIdentifier) string {
	parts := []string{}
	for _, part := range library {
		parts = append(parts, string(part))
	}
	return strings.Join(parts, "_")
}

func typeExprForMethod(request []Parameter, response []Parameter, name string) string {
	return fmt.Sprintf(`const $fidl.MethodType(
    request: %s,
	response: %s,
	name: r"%s",
  )`, formatParameterList(request), formatParameterList(response), name)
}

func typeExprForPrimitiveSubtype(val types.PrimitiveSubtype) string {
	t, ok := typeForPrimitiveSubtype[val]
	if !ok {
		log.Fatal("Unknown primitive subtype: ", val)
	}
	return fmt.Sprintf("const $fidl.%s()", t)
}

func libraryPrefix(library types.LibraryIdentifier) string {
	return fmt.Sprintf("lib$%s", formatLibraryName(library))
}

func isReservedWord(str string) bool {
	_, ok := reservedWords[str]
	return ok
}

func changeIfReserved(str string) string {
	if isReservedWord(str) {
		return str + "$"
	}
	return str
}

type compiler struct {
	decls   *types.DeclMap
	library types.LibraryIdentifier
}

func (c *compiler) inExternalLibrary(ci types.CompoundIdentifier) bool {
	if len(ci.Library) != len(c.library) {
		return true
	}
	for i, part := range c.library {
		if ci.Library[i] != part {
			return true
		}
	}
	return false
}

func (c *compiler) typeSymbolForCompoundIdentifier(ident types.CompoundIdentifier) string {
	t := fmt.Sprintf("k%s_Type", ident.Name)
	if c.inExternalLibrary(ident) {
		return fmt.Sprintf("%s.%s", libraryPrefix(ident.Library), t)
	}
	return t
}

func (c *compiler) compileUpperCamelIdentifier(val types.Identifier) string {
	return changeIfReserved(common.ToUpperCamelCase(string(val)))
}

func (c *compiler) compileLowerCamelIdentifier(val types.Identifier) string {
	return changeIfReserved(common.ToLowerCamelCase(string(val)))
}

func (c *compiler) compileCompoundIdentifier(val types.CompoundIdentifier) string {
	strs := []string{}
	if c.inExternalLibrary(val) {
		strs = append(strs, libraryPrefix(val.Library))
	}
	strs = append(strs, changeIfReserved(string(val.Name)))
	return strings.Join(strs, ".")
}

func (c *compiler) compileUpperCamelCompoundIdentifier(val types.CompoundIdentifier, ext string) string {
	str := changeIfReserved(common.ToUpperCamelCase(string(val.Name))) + ext
	val.Name = types.Identifier(str)
	return c.compileCompoundIdentifier(val)
}

func (c *compiler) compileLowerCamelCompoundIdentifier(val types.CompoundIdentifier, ext string) string {
	str := changeIfReserved(common.ToLowerCamelCase(string(val.Name))) + ext
	val.Name = types.Identifier(str)
	return c.compileCompoundIdentifier(val)
}

func (c *compiler) compileLiteral(val types.Literal) string {
	switch val.Kind {
	case types.StringLiteral:
		// TODO(abarth): Escape more characters (e.g., newline).
		return fmt.Sprintf("%q", val.Value)
	case types.NumericLiteral:
		// TODO(abarth): Values larger than max int64 need to be encoded in hex.
		return val.Value
	case types.TrueLiteral:
		return "true"
	case types.FalseLiteral:
		return "false"
	case types.DefaultLiteral:
		return "default"
	default:
		log.Fatal("Unknown literal kind: ", val.Kind)
		return ""
	}
}

func (c *compiler) compileConstant(val types.Constant, t *Type) string {
	switch val.Kind {
	case types.IdentifierConstant:
		v := c.compileLowerCamelCompoundIdentifier(types.ParseCompoundIdentifier(val.Identifier), "")
		if t != nil && t.declType == types.EnumDeclType {
			v = fmt.Sprintf("%s.%s", t.Decl, v)
		}
		return v
	case types.LiteralConstant:
		return c.compileLiteral(val.Literal)
	default:
		log.Fatal("Unknown constant kind: ", val.Kind)
		return ""
	}
}

func (c *compiler) compilePrimitiveSubtype(val types.PrimitiveSubtype) string {
	if t, ok := declForPrimitiveType[val]; ok {
		return t
	}
	log.Fatal("Unknown primitive type: ", val)
	return ""
}

func (c *compiler) maybeCompileConstant(val *types.Constant, t *Type) string {
	if val == nil {
		return "null"
	}
	return c.compileConstant(*val, t)
}

func (c *compiler) compileType(val types.Type) Type {
	r := Type{}
	r.Nullable = val.Nullable
	switch val.Kind {
	case types.ArrayType:
		t := c.compileType(*val.ElementType)
		if len(t.typedDataDecl) > 0 {
			r.Decl = t.typedDataDecl
			r.SyncDecl = r.Decl
			r.AsyncDecl = r.Decl
		} else {
			r.Decl = fmt.Sprintf("List<%s>", t.Decl)
			r.SyncDecl = fmt.Sprintf("List<%s>", t.SyncDecl)
			r.AsyncDecl = fmt.Sprintf("List<%s>", t.AsyncDecl)

		}
		elementStr := fmt.Sprintf("element: %s", t.typeExpr)
		elementCountStr := fmt.Sprintf("elementCount: %s", formatInt(val.ElementCount))
		r.typeExpr = fmt.Sprintf("const $fidl.ArrayType<%s>(%s, %s)", r.Decl, elementStr, elementCountStr)
	case types.VectorType:
		t := c.compileType(*val.ElementType)
		if len(t.typedDataDecl) > 0 {
			r.Decl = t.typedDataDecl
			r.SyncDecl = r.Decl
			r.AsyncDecl = r.Decl
		} else {
			r.Decl = fmt.Sprintf("List<%s>", t.Decl)
			r.SyncDecl = fmt.Sprintf("List<%s>", t.SyncDecl)
			r.AsyncDecl = fmt.Sprintf("List<%s>", t.AsyncDecl)
		}
		elementStr := fmt.Sprintf("element: %s", t.typeExpr)
		maybeElementCountStr := fmt.Sprintf("maybeElementCount: %s", formatInt(val.ElementCount))
		nullableStr := fmt.Sprintf("nullable: %s", formatBool(val.Nullable))
		r.typeExpr = fmt.Sprintf("const $fidl.VectorType<%s>(%s, %s, %s)",
			r.Decl, elementStr, maybeElementCountStr, nullableStr)
	case types.StringType:
		r.Decl = "String"
		r.SyncDecl = r.Decl
		r.AsyncDecl = r.Decl
		r.typeExpr = fmt.Sprintf("const $fidl.StringType(maybeElementCount: %s, nullable: %s)",
			formatInt(val.ElementCount), formatBool(val.Nullable))
	case types.HandleType:
		switch val.HandleSubtype {
		case "channel":
			r.Decl = "Channel"
		case "eventpair":
			r.Decl = "EventPair"
		case "socket":
			r.Decl = "Socket"
		case "vmo":
			r.Decl = "Vmo"
		default:
			r.Decl = "Handle"
		}
		r.SyncDecl = r.Decl
		r.AsyncDecl = r.Decl
		r.typeExpr = fmt.Sprintf("const $fidl.%sType(nullable: %s)",
			r.Decl, formatBool(val.Nullable))
	case types.RequestType:
		compound := types.ParseCompoundIdentifier(val.RequestSubtype)
		t := c.compileUpperCamelCompoundIdentifier(compound, "")
		r.Decl = fmt.Sprintf("$fidl.InterfaceRequest<%s>", t)
		if c.inExternalLibrary(compound) {
			r.SyncDecl = fmt.Sprintf("$fidl.InterfaceRequest<sync$%s>", t)
		} else {
			r.SyncDecl = fmt.Sprintf("$fidl.InterfaceRequest<$sync.%s>", t)
		}
		r.AsyncDecl = r.Decl
		r.typeExpr = fmt.Sprintf("const $fidl.InterfaceRequestType<%s>(nullable: %s)",
			t, formatBool(val.Nullable))
	case types.PrimitiveType:
		r.Decl = c.compilePrimitiveSubtype(val.PrimitiveSubtype)
		r.SyncDecl = r.Decl
		r.AsyncDecl = r.Decl
		r.typedDataDecl = typedDataDecl[val.PrimitiveSubtype]
		r.typeExpr = typeExprForPrimitiveSubtype(val.PrimitiveSubtype)
	case types.IdentifierType:
		compound := types.ParseCompoundIdentifier(val.Identifier)
		t := c.compileUpperCamelCompoundIdentifier(compound, "")
		declType, ok := (*c.decls)[val.Identifier]
		if !ok {
			log.Fatal("Unknown identifier: ", val.Identifier)
		}
		r.declType = declType
		switch r.declType {
		case types.ConstDeclType:
			fallthrough
		case types.EnumDeclType:
			fallthrough
		case types.StructDeclType:
			fallthrough
		case types.TableDeclType:
			fallthrough
		case types.UnionDeclType:
			r.Decl = t
			if c.inExternalLibrary(compound) {
				r.SyncDecl = fmt.Sprintf("sync$%s", t)

			} else {
				r.SyncDecl = fmt.Sprintf("$sync.%s", t)
			}
			r.AsyncDecl = r.SyncDecl
			r.typeExpr = c.typeSymbolForCompoundIdentifier(types.ParseCompoundIdentifier(val.Identifier))
			if val.Nullable {
				r.typeExpr = fmt.Sprintf("const $fidl.PointerType<%s>(element: %s)",
					t, r.typeExpr)
			}
		case types.InterfaceDeclType:
			r.Decl = fmt.Sprintf("$fidl.InterfaceHandle<%s>", t)
			if c.inExternalLibrary(compound) {
				r.SyncDecl = fmt.Sprintf("$fidl.InterfaceHandle<sync$%s>", t)

			} else {
				r.SyncDecl = fmt.Sprintf("$fidl.InterfaceHandle<$sync.%s>", t)
			}
			r.AsyncDecl = r.Decl
			r.typeExpr = fmt.Sprintf("const $fidl.InterfaceHandleType<%s>(nullable: %s)",
				t, formatBool(val.Nullable))
		default:
			log.Fatal("Unknown declaration type: ", r.declType)
		}
	default:
		log.Fatal("Unknown type kind: ", val.Kind)
	}
	if r.AsyncDecl == "" {
		log.Fatalf("No AsyncDecl for %s", r.Decl)
	}
	if r.SyncDecl == "" {
		log.Fatalf("No SyncDecl for %s", r.Decl)
	}
	return r
}

func (c *compiler) compileConst(val types.Const) Const {
	r := Const{
		c.compileType(val.Type),
		c.compileLowerCamelCompoundIdentifier(types.ParseCompoundIdentifier(val.Name), ""),
		c.compileConstant(val.Value, nil),
		docString(val),
	}
	if r.Type.declType == types.EnumDeclType {
		r.Value = fmt.Sprintf("%s.%s", r.Type.Decl, r.Value)
	}
	return r
}

func (c *compiler) compileEnum(val types.Enum) Enum {
	ci := types.ParseCompoundIdentifier(val.Name)
	n := c.compileUpperCamelCompoundIdentifier(ci, "")
	e := Enum{
		n,
		[]EnumMember{},
		c.typeSymbolForCompoundIdentifier(ci),
		fmt.Sprintf("const $fidl.EnumType<%s>(type: %s, ctor: %s._ctor)", n, typeExprForPrimitiveSubtype(val.Type), n),
		docString(val),
	}
	for _, v := range val.Members {
		e.Members = append(e.Members, EnumMember{
			c.compileLowerCamelIdentifier(v.Name),
			c.compileConstant(v.Value, nil),
			docString(v),
		})
	}
	return e
}

func (c *compiler) compileParameterArray(val []types.Parameter) []Parameter {
	r := []Parameter{}

	for _, v := range val {
		t := c.compileType(v.Type)
		typeStr := fmt.Sprintf("type: %s", t.typeExpr)
		offsetStr := fmt.Sprintf("offset: %v", v.Offset)
		name := c.compileLowerCamelIdentifier(v.Name)
		convert := ""
		if t.declType == types.InterfaceDeclType {
			convert = "$fidl.convertInterfaceHandle"
		} else if v.Type.Kind == types.RequestType {
			convert = "$fidl.convertInterfaceRequest"
		}
		p := Parameter{
			Type:     t,
			Name:     name,
			Offset:   v.Offset,
			Convert:  convert,
			typeExpr: fmt.Sprintf("const $fidl.MemberType<%s>(%s, %s)", t.Decl, typeStr, offsetStr),
		}
		r = append(r, p)
	}

	return r
}

func (c *compiler) compileInterface(val types.Interface) Interface {
	ci := types.ParseCompoundIdentifier(val.Name)
	r := Interface{
		c.compileUpperCamelCompoundIdentifier(ci, ""),
		val.GetServiceName(),
		c.compileUpperCamelCompoundIdentifier(ci, "Data"),
		c.compileUpperCamelCompoundIdentifier(ci, "Proxy"),
		c.compileUpperCamelCompoundIdentifier(ci, "Binding"),
		c.compileUpperCamelCompoundIdentifier(ci, "Events"),
		[]Method{},
		false,
		docString(val),
	}

	if r.ServiceName == "" {
		r.ServiceName = "null"
	}

	for _, v := range val.Methods {
		name := c.compileLowerCamelIdentifier(v.Name)
		request := c.compileParameterArray(v.Request)
		response := c.compileParameterArray(v.Response)
		asyncResponseClass := ""
		if len(response) > 1 {
			asyncResponseClass = fmt.Sprintf("%s$%s$Response", r.Name, v.Name)
		}
		asyncResponseType := ""
		if v.HasResponse {
			if len(response) == 0 {
				asyncResponseType = "void"
			} else if len(response) == 1 {
				responseType := response[0].Type
				if responseType.SyncDecl != "" {
					asyncResponseType = responseType.Decl
				} else {
					asyncResponseType = responseType.Decl
				}
			} else {
				asyncResponseType = asyncResponseClass
			}
		}
		_, transitional := v.LookupAttribute("Transitional")
		m := Method{
			v.Ordinal,
			fmt.Sprintf("_k%s_%s_Ordinal", r.Name, v.Name),
			name,
			v.HasRequest,
			request,
			v.RequestSize,
			v.HasResponse,
			response,
			v.ResponseSize,
			asyncResponseClass,
			asyncResponseType,
			fmt.Sprintf("%s%sCallback", r.Name, v.Name),
			fmt.Sprintf("_k%s_%s_Type", r.Name, v.Name),
			typeExprForMethod(request, response, fmt.Sprintf("%s.%s", r.Name, v.Name)),
			transitional,
			docString(v),
		}
		r.Methods = append(r.Methods, m)
		if !v.HasRequest && v.HasResponse {
			r.HasEvents = true
		}
	}

	return r
}

func (c *compiler) compileStructMember(val types.StructMember) StructMember {
	t := c.compileType(val.Type)

	defaultValue := ""
	if val.MaybeDefaultValue != nil {
		defaultValue = c.compileConstant(*val.MaybeDefaultValue, &t)
	}

	typeStr := fmt.Sprintf("type: %s", t.typeExpr)
	offsetStr := fmt.Sprintf("offset: %v", val.Offset)
	return StructMember{
		t,
		c.compileLowerCamelIdentifier(val.Name),
		defaultValue,
		val.Offset,
		fmt.Sprintf("const $fidl.MemberType<%s>(%s, %s)", t.Decl, typeStr, offsetStr),
		docString(val),
	}
}

func (c *compiler) compileStruct(val types.Struct) Struct {
	ci := types.ParseCompoundIdentifier(val.Name)
	r := Struct{
		c.compileUpperCamelCompoundIdentifier(ci, ""),
		[]StructMember{},
		c.typeSymbolForCompoundIdentifier(ci),
		"",
		false,
		docString(val),
	}

	var hasNullableField = false

	for _, v := range val.Members {
		var member = c.compileStructMember(v)
		if member.Type.Nullable {
			hasNullableField = true
		}
		r.Members = append(r.Members, member)
	}

	if len(r.Members) == 0 {
		r.Members = []StructMember{
			c.compileStructMember(types.EmptyStructMember("reserved")),
		}
	}

	r.HasNullableField = hasNullableField

	r.TypeExpr = fmt.Sprintf(`const $fidl.StructType<%s>(
  encodedSize: %v,
  members: %s,
  ctor: %s._ctor,
)`, r.Name, val.Size, formatStructMemberList(r.Members), r.Name)
	return r
}

func (c *compiler) compileTableMember(val types.TableMember) TableMember {
	t := c.compileType(val.Type)

	defaultValue := ""
	if val.MaybeDefaultValue != nil {
		defaultValue = c.compileConstant(*val.MaybeDefaultValue, &t)
	}

	return TableMember{
		Ordinal:      val.Ordinal,
		Type:         t,
		Name:         c.compileLowerCamelIdentifier(val.Name),
		DefaultValue: defaultValue,
		Documented:   docString(val),
	}
}

func (c *compiler) compileTable(val types.Table) Table {
	ci := types.ParseCompoundIdentifier(val.Name)
	r := Table{
		Name:       c.compileUpperCamelCompoundIdentifier(ci, ""),
		TypeSymbol: c.typeSymbolForCompoundIdentifier(ci),
		Documented: docString(val),
	}

	for _, v := range val.Members {
		r.Members = append(r.Members, c.compileTableMember(v))
	}

	r.TypeExpr = fmt.Sprintf(`const $fidl.TableType<%s>(
  encodedSize: %v,
  members: %s,
  ctor: %s._ctor,
)`, r.Name, val.Size, formatTableMemberList(r.Members), r.Name)
	return r
}

func (c *compiler) compileUnionMember(val types.UnionMember) UnionMember {
	t := c.compileType(val.Type)
	typeStr := fmt.Sprintf("type: %s", t.typeExpr)
	offsetStr := fmt.Sprintf("offset: %v", val.Offset)
	return UnionMember{
		t,
		c.compileLowerCamelIdentifier(val.Name),
		c.compileUpperCamelIdentifier(val.Name),
		val.Offset,
		fmt.Sprintf("const $fidl.MemberType<%s>(%s, %s)", t.Decl, typeStr, offsetStr),
		docString(val),
	}
}

func (c *compiler) compileUnion(val types.Union) Union {
	ci := types.ParseCompoundIdentifier(val.Name)
	r := Union{
		c.compileUpperCamelCompoundIdentifier(ci, ""),
		c.compileUpperCamelCompoundIdentifier(ci, "Tag"),
		[]UnionMember{},
		c.typeSymbolForCompoundIdentifier(ci),
		"",
		docString(val),
	}

	for _, v := range val.Members {
		r.Members = append(r.Members, c.compileUnionMember(v))
	}

	r.TypeExpr = fmt.Sprintf(`const $fidl.UnionType<%s>(
  encodedSize: %v,
  members: %s,
  ctor: %s._ctor,
)`, r.Name, val.Size, formatUnionMemberList(r.Members), r.Name)
	return r
}

// Compile the language independent type definition into the Dart-specific representation.
func Compile(r types.Root) Root {
	root := Root{}
	c := compiler{&r.Decls, types.ParseLibraryName(r.Name)}

	root.LibraryName = fmt.Sprintf("fidl_%s", formatLibraryName(c.library))

	for _, v := range r.Consts {
		root.Consts = append(root.Consts, c.compileConst(v))
	}

	for _, v := range r.Enums {
		root.Enums = append(root.Enums, c.compileEnum(v))
	}

	for _, v := range r.Interfaces {
		root.Interfaces = append(root.Interfaces, c.compileInterface(v))
	}

	for _, v := range r.Structs {
		root.Structs = append(root.Structs, c.compileStruct(v))
	}

	for _, v := range r.Tables {
		root.Tables = append(root.Tables, c.compileTable(v))
	}

	for _, v := range r.Unions {
		root.Unions = append(root.Unions, c.compileUnion(v))
	}

	for _, l := range r.Libraries {
		if l.Name == r.Name {
			// We don't need to import our own package.
			continue
		}
		library := types.ParseLibraryName(l.Name)
		root.Imports = append(root.Imports, Import{
			URL:       fmt.Sprintf("package:fidl_%s/fidl.dart", formatLibraryName(library)),
			LocalName: libraryPrefix(library),
			AsyncURL:  fmt.Sprintf("package:fidl_%s/fidl_async.dart", formatLibraryName(library)),
		})
	}

	return root
}
