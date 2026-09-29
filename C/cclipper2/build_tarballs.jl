# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "cclipper2"
version = v"0.1.0"

# The wrapper is hosted in Clipper.jl, next to the ccall sites that consume it.
sources = [
    GitSource("https://github.com/JuliaGeometry/Clipper.jl.git", "70dbd8c78ada6af5cc27f8aae8c3562e2bcc0475"),
]

# Bash recipe for building across all platforms
script = raw"""
cd ${WORKSPACE}/srcdir/Clipper.jl/deps/cwrapper
install -Dvm 644 cclipper2.h "${includedir}/cclipper2.h"

# A flat C ABI over Clipper2's C++ API, for FFI consumers such as Julia's ccall.
# One library, compiled -DUSINGZ and linked against libClipper2Z: Point64 then
# carries a third int64; the narrow {x,y} entry points construct it with z=0, and
# the *_z entry points expose it.
# USINGZ and CLIPPER2_HI_PRECISION must match how Clipper2_jll built libClipper2Z
# (both are PUBLIC defines there that change inline header code and Point64's layout).
# The -fvisibility flags keep the exports to the functions marked DLL_PUBLIC
# (no Clipper2/STL template instantiations); -L${prefix}/lib covers Windows, where
# ${libdir} is the DLL directory but the import library lands in ${prefix}/lib.
${CXX} -std=c++17 -O2 -fPIC -shared -DUSINGZ -DCLIPPER2_HI_PRECISION \
    -fvisibility=hidden -fvisibility-inlines-hidden \
    -I${includedir} \
    -o "${libdir}/libcclipper2.${dlext}" \
    cclipper2.cpp \
    -L${libdir} -L${prefix}/lib -lClipper2Z

# The wrapper is BSL-1.0, the same license as Clipper2, whose license text
# Clipper2_jll installs; Clipper.jl's own LICENSE.md (MIT) doesn't cover it.
install_license ${prefix}/share/licenses/Clipper2/LICENSE
"""

# Must match Clipper2_jll's platforms, since libcclipper2 links its C++ library.
platforms = supported_platforms()
platforms = expand_cxxstring_abis(platforms)

# The products that we will ensure are always built
products = [
    LibraryProduct("libcclipper2", :libcclipper2),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    # Exact pin: the wrapper compiles against Clipper2's C++ headers, and upstream
    # makes no ABI promise even across patch releases (1.2.3 renumbered JoinType),
    # so every Clipper2 bump needs a rebuild of this recipe.
    Dependency("Clipper2_jll"; compat="=2.0.1"),
]

# Build the tarballs, and possibly a `build.jl` as well.
# GCC 10 matches Clipper2_jll and is the newest compatible with julia_compat="1.6"
# (Julia 1.6 ships libstdc++ from GCC 10).
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; julia_compat="1.6", preferred_gcc_version = v"10")
