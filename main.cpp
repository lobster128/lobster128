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

// Project
#include "Vlobster_CPU.h"

class RAM_Manager {
    static constexpr auto bitmask = 0xffff;
    static constexpr auto blocksize = 0xffff;
    std::unordered_map<uint64_t, std::array<uint8_t, blocksize>> blocks;
public:
    RAM_Manager() = default;
    ~RAM_Manager() = default;

    std::unordered_map<uint64_t, std::array<uint8_t, blocksize>>::iterator get_block(uint64_t addr)
    {
        auto it = blocks.find(addr & (~bitmask));
        if(it == blocks.end())
        {
            auto arr = std::array<uint8_t, blocksize>();
            std::fill(arr.begin(), arr.end(), 0);
            blocks[addr & (~bitmask)] = arr;
            printf("mem_ballon: expanding by %zu bytes\n", blocksize);
        }
        return blocks.find(addr & (~bitmask));
    }

    void write(uint64_t addr, uint64_t data)
    {
        auto it = get_block(addr);
        it->second[(addr + 0) & bitmask] = static_cast<uint8_t>((data >> 0) & 0xff);
        it->second[(addr + 1) & bitmask] = static_cast<uint8_t>((data >> 8) & 0xff);
        it->second[(addr + 2) & bitmask] = static_cast<uint8_t>((data >> 16) & 0xff);
        it->second[(addr + 3) & bitmask] = static_cast<uint8_t>((data >> 24) & 0xff);
    }

    uint64_t read(uint64_t addr)
    {
        auto it = get_block(addr);
        uint64_t data = 0;
        data |= it->second[(addr + 0) & bitmask];
        data |= static_cast<uint64_t>(it->second[(addr + 0) & bitmask]) << 8;
        data |= static_cast<uint64_t>(it->second[(addr + 0) & bitmask]) << 16;
        data |= static_cast<uint64_t>(it->second[(addr + 0) & bitmask]) << 32;
        return data;
    }
};

int main(int argc, char **argv, char **env)
{
    // Create the system
    auto top = std::make_unique<Vlobster_CPU>();

    Verilated::debug(0);
    Verilated::randReset(2);
    Verilated::traceEverOn(true);
    Verilated::commandArgs(argc, argv);
    Verilated::mkdir("logs");

    auto ram = RAM_Manager();

    // Write bootrom
    ram.write(0xf800, 0b00010'00001'0000'00); // ADD R2, R1

    vluint64_t main_time = 0;
    while (!Verilated::gotFinish())
    {
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
        if(main_time >= 100)
        {
            break;
        }
        top->eval();

        top->rdy = 0;
        if(top->ce && top->clk)
        {
            if(top->we)
            {
                ram.write(top->addr_out, top->data_out);
                top->rdy = 1;
                printf("mem_ballon: write 0x%llx <- 0x%llx\n", top->addr_out, top->data_out);
            }
            else
            {
                top->data_in = ram.read(top->addr_in);
                top->rdy = 1;
                printf("mem_ballon: read 0x%llx -> %llx\n", top->addr_in, top->data_in);
            }
        }
    }
    top->final();

    //  Coverage analysis (since test passed)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    VerilatedCov::write("logs/coverage.dat");
#endif
    return 0;
}
