

//HAWK TEST

#include <stdio.h>

#define uint64_t unsigned long

#define HAWK_REG_BASE  0xfff5100000ULL
#define LST_ENTRY_CNT 16
uint64_t array1[512*LST_ENTRY_CNT];

int main(int argc, char ** argv) {
    uint64_t *addr;

    printf("\nHello World ..!\n");
    printf("Performing HAWK Test ..\n");
    for (int k = 0; k < 1; k++) {
      printf("Hello world, I am HART %d! Counting (%d of 32)...\n", argv[0][0], k);
    }
    for(int j=0;j<LST_ENTRY_CNT-1;j++) {
      printf("writing %d! \n", j);
      for (int i = 0; i < 64; i++)
        if (i<16)
          array1[j * 512 + i] = ((uint64_t) (j*16+i+1));//* 0x0101010101010101;
        else
          array1[j * 512 + i] = (uint64_t) 0x0;
    }
    printf("Accessing Compressed Page\n");
    printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",2,array1[2*512]);
    //Assert Interrupt
    addr = (uint64_t*)HAWK_REG_BASE;
    printf("HAWK LOW WATER MARK : Default Value = 0x%016x\n",*addr);
    printf("HAWK LOW WATER MARK : Writing Register with 0x13572468\n");
    *addr = 0x0100000000000004;
    printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",3,array1[3*512]);
    printf("HAWK LOW WATER MARK : Read back Value = 0x%016x\n",*addr);
    printf("HACD: Accesing Memory on 0x%llx, data = 0x%llx\n",3,array1[4*512]);
    printf("HAWK Test Done!..\n");
    return 0;
}

