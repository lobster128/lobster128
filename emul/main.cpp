// STL
#include <cstdio>
#include <memory>
#include <stdexcept>
#include <exception>
#include <unordered_map>
#include <array>

// Verilator
#include <verilated.h>
#include <verilated_vpi.h>

// SDL
#include <SDL2/SDL.h>
#include <SDL2/SDL_ttf.h>

// GDB stub
extern "C" {
#define GDBSTUB_IMPLEMENTATION 1
#define GDBSTUB_DEBUG 1
#include "gdbstub.h"
}

// Project
#include "Vlobster_CPU.h"
#include "ram.hpp"

typedef unsigned __int128 uint128_t;

typedef struct context
{
    context()
    {
        // Create the system
        top = std::make_unique<Vlobster_CPU>();

        Verilated::debug(0);
        Verilated::randReset(2);
        Verilated::traceEverOn(true);
        //Verilated::commandArgs(argc, argv);
        Verilated::mkdir("logs");
        
        // Write bootrom
        ram.write(0xf800 + (8 * 0), 0x02000a0002401200);
        ram.write(0xf800 + (8 * 1), 0x0280220002c04200);
        ram.write(0xf800 + (8 * 2), 0x0200830002400301);
        ram.write(0xf800 + (8 * 3), 0x0280030202c00304);
        ram.write(0xf800 + (8 * 4), 0x0200c43f02400480);
        ram.write(0xf800 + (8 * 5), 0x0280fcff02680000);
    }

    ~context()
    {
        top->final();
        //  Coverage analysis (since test passed)
#if VM_COVERAGE
        Verilated::mkdir("logs");
        VerilatedCov::write("logs/coverage.dat");
#endif
    }

    void step(void)
    {
        top->rst = (main_time < 10) ? 1 : 0;
        top->clk = !top->clk;
        top->rdy = 0;
        if (top->ce && top->clk)
        {
            if (top->we)
            {
                ram.write(top->addr_out, top->data_out);
                printf("mem_ballon: write 0x%llx <- 0x%llx\n", top->addr_out, top->data_out);
            }
            top->data_in = ram.read(top->addr_in);
            printf("mem_ballon: read 0x%llx -> %llx\n", top->addr_in, top->data_in);
            top->rdy = 1;
        }
        top->eval();
        main_time++;
    }

    uint128_t get_reg(int regnum)
    {
        uint128_t val = top->lobster_CPU__DOT__execman__DOT__gp_regs[regnum][0];
        val |= (uint128_t)top->lobster_CPU__DOT__execman__DOT__gp_regs[regnum][1] << 32;
        val |= (uint128_t)top->lobster_CPU__DOT__execman__DOT__gp_regs[regnum][2] << 64;
        val |= (uint128_t)top->lobster_CPU__DOT__execman__DOT__gp_regs[regnum][3] << 96;
        return val;
    }

    std::unique_ptr<Vlobster_CPU> top;
    RAM_Manager ram;
    int count = 0;
    int main_time = 0;
} context_t;

const char TARGET_CONFIG[] =
    "<?xml version=\"1.0\"?>"
    "<!DOCTYPE feature SYSTEM \"gdb-target.dtd\">"
    "<target version=\"1.0\">"
    "</target>";

const char MEMORY_MAP[] =
    "<?xml version=\"1.0\"?>"
    "<memory-map>"
    "</memory-map>";

void gdb_connected(context_t *ctx)
{
    printf("Connected\n");
}

void gdb_disconnected(context_t *ctx)
{
    printf("Disconnected\n");
}

void gdb_start(context_t *ctx)
{
    printf("Starting\n");
}

void gdb_stop(context_t *ctx)
{
    printf("Stopping\n");
}

void gdb_step(context_t *ctx)
{
    printf("Stepping\n");
}

void gdb_set_breakpoint(context_t *ctx, uint32_t address)
{
    printf("Set breakpoint %08X\n", address);
}

void gdb_clear_breakpoint(context_t *ctx, uint32_t address)
{
    printf("Clear breakpoint %08X\n", address);
}

ssize_t gdb_get_memory(context_t *ctx, char *buffer, size_t buffer_length, uint32_t address, size_t length)
{
    printf("Getting memory %08X, %08lX\n", address, length);
    if(length == 8) { // 64
        return snprintf(buffer, buffer_length, "%016lx", ctx->ram.read(address));
    } else if(length == 4) { // 32
        return snprintf(buffer, buffer_length, "%08lx", ctx->ram.read(address) & (0xffffffff << ((address & 0x01) * 32)));
    } else if(length == 2) { // 16
        return snprintf(buffer, buffer_length, "%04lx", ctx->ram.read(address) & (0xffff << ((address & 0x03) * 16)));
    } else if(length == 1) { // 8
        return snprintf(buffer, buffer_length, "%02lx", ctx->ram.read(address) & (0xff << ((address & 0x07) * 8)));
    }
    return snprintf(buffer, buffer_length, "00000000");
}

ssize_t gdb_get_register_value(context_t *ctx, char *buffer, size_t buffer_length, int reg)
{
    printf("Getting register value #%d\n", reg);
    uint128_t val = ctx->get_reg(reg);
    return snprintf(buffer, buffer_length, "%08llx%08llx", (uint64_t)(val >> 64), (uint64_t)val);
}

ssize_t gdb_get_general_registers(context_t *ctx, char *buffer, size_t buffer_length)
{
    printf("Getting general registers\n");
    return snprintf(buffer, buffer_length, "00000000");
}

bool at_breakpoint()
{
    // Detect breakpoint logic
    return false;
}

int main(int argc, char **argv, char **env)
{
    context_t ctx;

    struct gdbstub_config config;
    config.port = 1234;
    config.user_data = &ctx;
    config.connected = (gdbstub_connected_t)gdb_connected;
    config.disconnected = (gdbstub_disconnected_t)gdb_disconnected;
    config.start = (gdbstub_start_t)gdb_start;
    config.stop = (gdbstub_stop_t)gdb_stop;
    config.step = (gdbstub_step_t)gdb_step;
    config.set_breakpoint = (gdbstub_set_breakpoint_t)gdb_set_breakpoint;
    config.clear_breakpoint = (gdbstub_clear_breakpoint_t)gdb_clear_breakpoint;
    config.get_memory = (gdbstub_get_memory_t)gdb_get_memory;
    config.get_register_value = (gdbstub_get_register_value_t)gdb_get_register_value;
    config.get_general_registers = (gdbstub_get_general_registers_t)gdb_get_general_registers;
    config.target_config = TARGET_CONFIG;
    config.target_config_length = sizeof(TARGET_CONFIG);
    config.memory_map = MEMORY_MAP;
    config.memory_map_length = sizeof(MEMORY_MAP);

    gdbstub_t *gdb = gdbstub_init(config);
    if (!gdb)
    {
        fprintf(stderr, "failed to create gdbstub\n");
        return 1;
    }

    while (!Verilated::gotFinish())
    {
        if (at_breakpoint())
        {
            gdbstub_breakpoint_hit(gdb);
        }

        ctx.count = 50;
        while (ctx.count)
        {
            ctx.step();
            ctx.count--;
        }
        break;
#if 0
        gdbstub_tick(gdb);
#endif
    }
    gdbstub_term(gdb);
    return 0;
}
