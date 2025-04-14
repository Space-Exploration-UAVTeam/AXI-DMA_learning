#ifndef HW_MISC_H
#define HW_MISC_H
#include <xil_types.h>


#define BLOCK_SIZE 4096

#define USER_LED 47   // user_led in MicroZed
#define PLATFORM_EMAC_BASEADDR   XPAR_XEMACPS_0_BASEADDR

void led_init();
void led_set(u8 v);
void led_blink();

u32 read_pl_reg(u16 addr);
void write_pl_reg(u16 addr, u32 value);

void Usr_HDL_Intr_Handler(void *param);
void AXI_DMA_Tx_Intr_Handler(void *Callback);
void AXI_DMA_Rx_Intr_Handler(void *Callback);
int RUN_DMA_IN(u8 *pbuf);
int RUN_DMA_OUT(u8 *pbuf);

#define DMA_CBF_LEN (BLOCK_SIZE*32)
typedef struct
{
	u32 ptr_write;
	u32 ptr_read;
	u8 *pbuf;  // point to nearest 4KB alignment as buf base
	u8 buf[DMA_CBF_LEN+BLOCK_SIZE];

} dma_cbf_struct;
dma_cbf_struct dma_cbf;
void init_dma_cbf(dma_cbf_struct* p_cbf);

void disp_buff(const u8 *buff, const int size, u8 mode);

#endif
