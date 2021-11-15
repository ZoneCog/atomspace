#
# OpenCogGenCxxTypes.cmake
#
# Definitions for automatically building the four C++ AtomTypes
# defintion files, given a master file `atom_types.script`.
#
# Example usage:
# OPENCOG_CXX_ATOMTYPES(atom_types.script
#                       atom_types.h atom_types.definitions atom_types.inheritance)
#
# The name of the fourth file is always hard-coded to `atom_names.h`.
#
# ----------------------------------------------------------------------

# Write out the initial boilerplate for the four C++ files.

MACRO(OPENCOG_CXX_SETUP HEADER_FILE DEFINITIONS_FILE INHERITANCE_FILE)

	IF (NOT HEADER_FILE)
		MESSAGE(FATAL_ERROR "OPENCOG_CXX_ATOMTYPES missing HEADER_FILE")
	ENDIF (NOT HEADER_FILE)

	IF (NOT DEFINITIONS_FILE)
		MESSAGE(FATAL_ERROR "OPENCOG_CXX_ATOMTYPES missing DEFINITIONS_FILE")
	ENDIF (NOT DEFINITIONS_FILE)

	IF (NOT INHERITANCE_FILE)
		MESSAGE(FATAL_ERROR "OPENCOG_CXX_ATOMTYPES missing INHERITANCE_FILE")
	ENDIF (NOT INHERITANCE_FILE)

	SET(TMPHDR_FILE ${CMAKE_BINARY_DIR}/tmp_types.h)
	SET(CNAMES_FILE ${CMAKE_BINARY_DIR}/atom_names.h)

	MESSAGE(DEBUG "Generating C++ Atom Type defintions from ${SCRIPT_FILE}.")

	SET(CLASSSERVER_REFERENCE "opencog::nameserver().")
	SET(CLASSSERVER_INSTANCE "opencog::nameserver()")

	FILE(WRITE "${TMPHDR_FILE}"
		"/* File automatically generated by the macro OPENCOG_ADD_ATOM_TYPES. Do not edit */\n"
		"#include <opencog/atoms/atom_types/types.h>\nnamespace opencog\n{\n"
	)
	FILE(WRITE "${DEFINITIONS_FILE}"
		"/* File automatically generated by the macro OPENCOG_ADD_ATOM_TYPES.  Do not edit */\n"
		"#include <opencog/atoms/atom_types/NameServer.h>\n"
		"#include <opencog/atoms/atom_types/atom_types.h>\n"
		"#include <opencog/atoms/atom_types/types.h>\n"
		"#include \"${HEADER_FILE}\"\n"
	)

	# We need to touch the class-server before doing anything.
	# This is in order to guarantee that the main atomspace types
	# get created before other derived types.
	#
	# There's still a potentially nasty bug here: if some third types.script
	# file depends on types defined in a second file, but the third initializer
	# runs before the second, then any atoms in that third file that inherit
	# from the second will get a type of zero.  This will crash code later on.
	# The only fix for this is to make sure that the third script forces the
	# initailzers for the second one to run first. Hopefully, the programmer
	# will figure this out, before the bug shows up. :-)
	FILE(WRITE "${INHERITANCE_FILE}"
		"/* File automatically generated by the macro OPENCOG_ADD_ATOM_TYPES. Do not edit */\n\n"
		"/* Touch the server before adding types. */\n"
		"${CLASSSERVER_INSTANCE};\n"
	)

	FILE(WRITE "${CNAMES_FILE}"
		"/* File automatically generated by the macro OPENCOG_ADD_ATOM_TYPES. Do not edit */\n"
		"#include <opencog/atoms/atom_types/atom_types.h>\n"
		"#include <opencog/atoms/base/Handle.h>\n"
		"#include <opencog/atoms/base/Node.h>\n"
		"#include <opencog/atoms/base/Link.h>\n\n"
		"namespace opencog {\n\n"
		"#define NODE_CTOR(FUN,TYP) inline Handle FUN(std::string name) {\\\n"
		"    return createNode(TYP, std::move(name)); }\n\n"
		"#define LINK_CTOR(FUN,TYP) template<typename ...Atoms>\\\n"
		"    inline Handle FUN(Atoms const&... atoms) {\\\n"
		"       return createLink(TYP, atoms...); }\n\n"
	)

ENDMACRO()

# ------------
# Print out the C++ definitions
MACRO(OPENCOG_CXX_WRITE_DEFS)

	IF (NOT "${TYPE}" STREQUAL "NOTYPE")
		FILE(APPEND "${TMPHDR_FILE}" "extern opencog::Type ${TYPE};\n")
		FILE(APPEND "${DEFINITIONS_FILE}"  "opencog::Type opencog::${TYPE};\n")
	ELSE (NOT "${TYPE}" STREQUAL "NOTYPE")
		FILE(APPEND "${TMPHDR_FILE}"
			"#ifndef _OPENCOG_NOTYPE_\n"
			"#define _OPENCOG_NOTYPE_\n"
			"// Set notype's code with the last possible Type code\n"
			"static const opencog::Type ${TYPE}=((Type) -1);\n"
			"#endif // _OPENCOG_NOTYPE_\n"
		)
	ENDIF (NOT "${TYPE}" STREQUAL "NOTYPE")

	IF (ISNODE STREQUAL "NODE" AND
		NOT SHORT_NAME STREQUAL "" AND
		NOT SHORT_NAME STREQUAL "Type")
		FILE(APPEND "${CNAMES_FILE}" "NODE_CTOR(${SHORT_NAME}, ${TYPE})\n")
	ENDIF ()
	IF (ISLINK STREQUAL "LINK" AND
		NOT SHORT_NAME STREQUAL "" AND
		NOT SHORT_NAME STREQUAL "Atom" AND
		NOT SHORT_NAME STREQUAL "Notype" AND
		NOT SHORT_NAME STREQUAL "Type" AND
		NOT SHORT_NAME STREQUAL "TypeSet" AND
		NOT SHORT_NAME STREQUAL "Arity")
		FILE(APPEND "${CNAMES_FILE}" "LINK_CTOR(${SHORT_NAME}, ${TYPE})\n")
	ENDIF ()
	# Special case...
	IF (ISNODE STREQUAL "NODE" AND
		SHORT_NAME STREQUAL "Type")
		FILE(APPEND "${CNAMES_FILE}" "NODE_CTOR(TypeNode, ${TYPE})\n")
	ENDIF ()
	IF (ISLINK STREQUAL "LINK" AND
		SHORT_NAME STREQUAL "Type")
		FILE(APPEND "${CNAMES_FILE}" "LINK_CTOR(TypeLink, ${TYPE})\n")
	ENDIF ()
	IF (ISLINK STREQUAL "LINK" AND
		SHORT_NAME STREQUAL "TypeSet")
		FILE(APPEND "${CNAMES_FILE}" "LINK_CTOR(TypeIntersection, ${TYPE})\n")
	ENDIF ()
	IF (ISLINK STREQUAL "LINK" AND
		SHORT_NAME STREQUAL "Arity")
		FILE(APPEND "${CNAMES_FILE}" "LINK_CTOR(ArityLink, ${TYPE})\n")
	ENDIF ()

	# ------------------------------------
	# Create the type inheritance C++ file.

	IF (PARENT_TYPES)
		STRING(REGEX REPLACE "[ 	]*,[ 	]*" ";" PARENT_TYPES "${PARENT_TYPES}")
		FOREACH (PARENT_TYPE ${PARENT_TYPES})
			# Skip inheritance of the special "notype" class; we could move
			# this test up but it was left here for simplicity's sake
			IF (NOT "${TYPE}" STREQUAL "NOTYPE")
				FILE(APPEND "${INHERITANCE_FILE}"
					"opencog::${TYPE} = ${CLASSSERVER_REFERENCE}"
					"declType(opencog::${PARENT_TYPE}, \"${TYPE_NAME}\");\n"
				)
			ENDIF (NOT "${TYPE}" STREQUAL "NOTYPE")
		ENDFOREACH (PARENT_TYPE)
	ELSE (PARENT_TYPES)
		IF (NOT "${TYPE}" STREQUAL "NOTYPE")
			FILE(APPEND "${INHERITANCE_FILE}"
				"opencog::${TYPE} = ${CLASSSERVER_REFERENCE}"
				"declType(opencog::${TYPE}, \"${TYPE_NAME}\");\n"
			)
		ENDIF (NOT "${TYPE}" STREQUAL "NOTYPE")
	ENDIF (PARENT_TYPES)
ENDMACRO(OPENCOG_CXX_WRITE_DEFS)

# Macro called up the conclusion of the scripts file.
MACRO(OPENCOG_CXX_TEARDOWN HEADER_FILE)
	FILE(APPEND "${TMPHDR_FILE}" "} // namespace opencog\n")

	FILE(APPEND "${CNAMES_FILE}"
		"#undef NODE_CTOR\n"
		"#undef LINK_CTOR\n"
		"} // namespace opencog\n"
	)

	# Must be last, so that all writing has completed *before* the
	# file appears in the filesystem. Without this, parallel-make
	# will sometimes use an incompletely-written file.
	FILE(RENAME "${TMPHDR_FILE}" "${HEADER_FILE}")
ENDMACRO()

# ------------
# Main entry point.
MACRO(OPENCOG_CXX_ATOMTYPES SCRIPT_FILE HEADER_FILE DEFINITIONS_FILE INHERITANCE_FILE)
	OPENCOG_CXX_SETUP(${HEADER_FILE} ${DEFINITIONS_FILE} ${INHERITANCE_FILE})

	FILE(STRINGS "${SCRIPT_FILE}" TYPE_SCRIPT_CONTENTS)
	FOREACH (LINE ${TYPE_SCRIPT_CONTENTS})
		OPENCOG_TYPEINFO_REGEX()
		IF (MATCHED AND CMAKE_MATCH_1)

			OPENCOG_TYPEINFO_SETUP()
			OPENCOG_CXX_WRITE_DEFS()    # Print out the C++ definitions
		ELSEIF (NOT MATCHED)
			MESSAGE(FATAL_ERROR "Invalid line in ${SCRIPT_FILE} file: [${LINE}]")
		ENDIF ()
	ENDFOREACH (LINE)

	OPENCOG_CXX_TEARDOWN(${HEADER_FILE})
ENDMACRO()

#####################################################################
