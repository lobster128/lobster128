// STL
#include <cstdio>
#include <memory>
#include <stdexcept>
#include <exception>

// Verilator
#include <verilated.h>
#include <verilated_vpi.h>

// SDL
#include <SDL2/SDL.h>
#include <SDL2/SDL_ttf.h>

// Project
#include "Vlobster_CPU.h"

int main(int argc, char **argv, char **env)
{
    // Create the system
    auto top = std::make_unique<Vlobster_CPU>();

    Verilated::debug(0);
    Verilated::randReset(2);
    Verilated::traceEverOn(true);
    Verilated::commandArgs(argc, argv);
    Verilated::mkdir("logs");

    auto ram = std::unique_ptr<uint8_t[]>(new uint8_t[65535]);

    vluint64_t main_time = 0;
    while (!Verilated::gotFinish())
    {
        if(top->ce && top->clk)
        {
            if(top->we)
            {
                ram[top->addr_out & 0xFFFF] = top->data_out;
                top->rdy = 1;
                printf("WRITE 0x%llx <- 0x%llx\n", top->addr_out, top->data_out);
            }
            else
            {
                top->data_in = ram[top->addr_in & 0xFFFF];
                top->rdy = 1;
                printf("READ 0x%llx -> %llx\n", top->addr_in, top->data_in);
            }
        }
        else
        {
            top->rdy = 0;
        }

        top->rst = (main_time < 10) ? 1 : 0;
        top->clk = !top->clk;
        main_time++;
#if VM_COVERAGE
        if (main_time < 5)
        {
            // Zero coverage if still early in reset, otherwise toggles there may
            // falsely indicate a signal is covered
            VerilatedCov::zero();
        }
#endif
        top->eval();
    }
    top->final();

    //  Coverage analysis (since test passed)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    VerilatedCov::write("logs/coverage.dat");
#endif
    return 0;
}
