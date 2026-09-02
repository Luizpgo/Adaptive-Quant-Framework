#ifndef __AQF_DETERMINISTIC_RNG_MQH__
#define __AQF_DETERMINISTIC_RNG_MQH__

//+------------------------------------------------------------------+
//| Deterministic RNG                                                |
//| AQF v0.11.3 - validation RNG integrity fix                       |
//|                                                                  |
//| Previous validation RNG issue:                                   |
//| an LCG with odd multiplier/increment combined with "% 2" makes   |
//| the least-significant bit alternate deterministically 0/1.       |
//| That invalidates a 50/50 directional randomization test.         |
//|                                                                  |
//| Fix: xorshift32 + HIGH-bit binary choice.                        |
//| Random indices use multiply-high mapping rather than low-bit      |
//| modulo. Fixed seeds remain intentional for reproducibility.       |
//+------------------------------------------------------------------+

class CAQFDeterministicRNG
{
public:

   uint NextUInt(uint &state)
   {
      if(state == 0)
         state = 0xA341316C;

      uint x = state;

      x ^= (x << 13);
      x ^= (x >> 17);
      x ^= (x << 5);

      if(x == 0)
         x = 0xA341316C;

      state = x;
      return x;
   }

   bool NextBool(uint &state)
   {
      uint value = NextUInt(state);

      return ((value & 0x80000000) != 0);
   }

   int NextIndex(uint &state, const int count)
   {
      if(count <= 1)
         return 0;

      uint value = NextUInt(state);

      ulong product =
         (ulong)value *
         (ulong)count;

      return (int)(product >> 32);
   }
};

#endif
