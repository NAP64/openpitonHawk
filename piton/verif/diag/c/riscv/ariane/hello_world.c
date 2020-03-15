// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
// Date: 26.11.2018
// Description: Simple hello world program that prints 32 times "hello world".
//

#include <stdio.h>

#define HACD_BASE    0xfff5100000ULL

#define HAWK_MEM_BASE 0xfff6100000ULL

int main(int argc, char ** argv) {

  for (int k = 0; k < 1; k++) {
    // assemble number and print
    printf("Hello world, I am HART %d! Counting (%d of 32)...\n", argv[0][0], k);
  }

  //Generating Interrupt

      printf("HACD: Accessing HAWK \n");
      uint64_t *addr;
      
      addr = (uint64_t*)(HACD_BASE);
      printf("HACD: Cntrl result = 0x%016x\n",*addr);
      printf("Writing Control Register.\n");
      *addr = (uint32_t) 0x1;
      printf("HACD: Cntrl result = 0x%016x\n",*addr);
      
      addr = (uint64_t*)(HACD_BASE+4);
      printf("HACD: Low water mark result = 0x%016x\n",*addr);
      printf("Writing Low WaterMark Register.\n");
      *addr = (uint32_t) 0x1234;
      printf("HACD: Low water mark result = 0x%016x\n",*addr);


  printf("Done!\n");

  return 0;
}

