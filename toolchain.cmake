# 目标系统
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm64)

# 标记为交叉编译
set(CMAKE_CROSSCOMPILING TRUE)

# 工具链路径
set(TOOLCHAIN_DIR
    /home/jiewen/work2/rk3568_linux_5.10/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu
)

# 编译器设置
set(CMAKE_C_COMPILER ${TOOLCHAIN_DIR}/bin/aarch64-none-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_DIR}/bin/aarch64-none-linux-gnu-g++)
set(CMAKE_ASM_COMPILER ${TOOLCHAIN_DIR}/bin/aarch64-none-linux-gnu-as)

# Sysroot路径（使用完整的绝对路径
set(SYSROOT_PATH
    /home/jiewen/work2/rk3568_linux_5.10/buildroot/output/rockchip_rk3568/host/aarch64-buildroot-linux-gnu/sysroot
)

set(CMAKE_SYSROOT ${SYSROOT_PATH})
set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})

# 为编译器添加显式的sysroot标志
set(CMAKE_C_FLAGS_INIT "--sysroot=${SYSROOT_PATH}")
set(CMAKE_CXX_FLAGS_INIT "--sysroot=${SYSROOT_PATH}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "--sysroot=${SYSROOT_PATH}")

# 手动添加链接器搜索路径
set(CMAKE_EXE_LINKER_FLAGS_INIT
    "${CMAKE_EXE_LINKER_FLAGS_INIT} -L${SYSROOT_PATH}/lib -L${SYSROOT_PATH}/usr/lib"
)
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${CMAKE_EXE_LINKER_FLAGS_INIT}")

# 查找行为规则
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# CPU架构类型
set(ARM_CPU_TYPE cortex-a55) # RK3568使用Cortex-A55

# 交叉编译前缀
set(CROSS_COMPILE_PREFIX ${TOOLCHAIN_DIR}/bin/aarch64-none-linux-gnu)

# 添加必要的链接器路径
set(CMAKE_C_STANDARD_LIBRARIES
    "${CMAKE_C_STANDARD_LIBRARIES} -L${SYSROOT_PATH}/lib -L${SYSROOT_PATH}/usr/lib"
)
