#ifndef __RAM_HPP__
#define __RAM_HPP__ 1

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
        it->second[(addr + 4) & bitmask] = static_cast<uint8_t>((data >> 32) & 0xff);
        it->second[(addr + 5) & bitmask] = static_cast<uint8_t>((data >> 40) & 0xff);
        it->second[(addr + 6) & bitmask] = static_cast<uint8_t>((data >> 48) & 0xff);
        it->second[(addr + 7) & bitmask] = static_cast<uint8_t>((data >> 56) & 0xff);
    }

    uint64_t read(uint64_t addr)
    {
        auto it = get_block(addr);
        uint64_t data = 0;
        data |= it->second[(addr + 0) & bitmask];
        data |= static_cast<uint64_t>(it->second[(addr + 1) & bitmask]) << 8;
        data |= static_cast<uint64_t>(it->second[(addr + 2) & bitmask]) << 16;
        data |= static_cast<uint64_t>(it->second[(addr + 3) & bitmask]) << 24;
        data |= static_cast<uint64_t>(it->second[(addr + 4) & bitmask]) << 32;
        data |= static_cast<uint64_t>(it->second[(addr + 5) & bitmask]) << 40;
        data |= static_cast<uint64_t>(it->second[(addr + 6) & bitmask]) << 48;
        data |= static_cast<uint64_t>(it->second[(addr + 7) & bitmask]) << 56;
        data = _bswap64(data);
        return data;
    }
};

#endif
