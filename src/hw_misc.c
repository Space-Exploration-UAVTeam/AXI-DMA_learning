#include "xil_types.h"
#include "xil_exception.h"
#include "xgpiops.h"
#include "xscugic.h"
#include "xaxidma.h"
#include "hw_misc.h"

u8 led_blink_mode;

XGpioPs Gpio;
void led_init()
{
	int Status;
	XGpioPs_Config *ConfigPtr;

	ConfigPtr = XGpioPs_LookupConfig(XPAR_PS7_GPIO_0_DEVICE_ID);
	Status = XGpioPs_CfgInitialize(&Gpio, ConfigPtr,ConfigPtr->BaseAddr);
	if (Status != XST_SUCCESS)
		return;

	XGpioPs_SetDirectionPin(&Gpio, USER_LED, 1);
	XGpioPs_SetOutputEnablePin(&Gpio, USER_LED, 1);
	led_blink_mode=0;
}

void led_set(u8 v)
{
	XGpioPs_WritePin(&Gpio, USER_LED, v);
}


// This function will be called every 250ms-TcpFastTmrFlag set (in main.c)
void led_blink()
{
	static unsigned char v=0;

	switch(led_blink_mode&0x03)
	{
	case 0:  // 0.25Hz
		led_set((v>>3)&0x1);
		break;
	case 1:  // 0.5Hz
		led_set((v>>2)&0x1);
		break;
	case 2: // 1Hz
		led_set((v>>1)&0x1);
		break;
	case 3: // 2Hz
		led_set((v>>0)&0x1);
		break;
	default:
		break;
	}
	v++;
}

u32 read_pl_reg(u16 addr)
{
	u32 v;
	v=Xil_In32(XPAR_USR_HDL_0_S00_AXI_BASEADDR+addr);
	return v;
}

void write_pl_reg(u16 addr, u32 value)
{
	Xil_Out32(XPAR_USR_HDL_0_S00_AXI_BASEADDR+addr, value);
}


///////////////////////////////////////////////////////////////////////////////////////
// Interrupt handle for Usr_HDL
void Usr_HDL_Intr_Handler(void *param)
{
    static int int_cnt = 0;
    xil_printf("Usr_HDL int count= %d\r\n",int_cnt++);
}

static volatile int Tx_Done;
static volatile int Tx_Err;
static volatile int Rx_Done;
static volatile int Rx_Err;
XAxiDma AxiDma;
#define RESET_TIMEOUT_COUNTER	10000    // Timeout loop counter for reset

// AXI DMA TX interrupt handler function
void AXI_DMA_Tx_Intr_Handler(void *Callback)
{
	u32 irq_vec;
	int TimeOut;
	XAxiDma *AxiDmaInst = (XAxiDma *)Callback;

	irq_vec = XAxiDma_IntrGetIrq(AxiDmaInst, XAXIDMA_DMA_TO_DEVICE); //Read pending interrupts
	XAxiDma_IntrAckIrq(AxiDmaInst, irq_vec, XAXIDMA_DMA_TO_DEVICE); //Acknowledge pending interrupts

	if (!(irq_vec & XAXIDMA_IRQ_ALL_MASK)) // do nothing if no irq_vec bit set
		return;

	if ((irq_vec & XAXIDMA_IRQ_ERROR_MASK)) { // error
		Tx_Err = 1;
		XAxiDma_Reset(AxiDmaInst);
		TimeOut = RESET_TIMEOUT_COUNTER;
		while (TimeOut) {
			if (XAxiDma_ResetIsDone(AxiDmaInst))
				break;
			TimeOut -= 1;
		}
		return;
	}

	if ((irq_vec & XAXIDMA_IRQ_IOC_MASK)) //completion
		Tx_Done = 1;
}

// AXI DMA RX interrupt handler function
void AXI_DMA_Rx_Intr_Handler(void *Callback)
{
	u32 irq_vec;
	int TimeOut;
	XAxiDma *AxiDmaInst = (XAxiDma *)Callback;

	irq_vec = XAxiDma_IntrGetIrq(AxiDmaInst, XAXIDMA_DEVICE_TO_DMA); //Read pending interrupts
	XAxiDma_IntrAckIrq(AxiDmaInst, irq_vec, XAXIDMA_DEVICE_TO_DMA);  //Acknowledge pending interrupts

	if (!(irq_vec & XAXIDMA_IRQ_ALL_MASK))  // do nothing if no irq_vec bit set
		return;

	if ((irq_vec & XAXIDMA_IRQ_ERROR_MASK)) {  //error
		Rx_Err = 1;
		XAxiDma_Reset(AxiDmaInst); // maybe failed and hang here , to be fixed?
		TimeOut = RESET_TIMEOUT_COUNTER;
		while (TimeOut) {
			if(XAxiDma_ResetIsDone(AxiDmaInst))
				break;
			TimeOut -= 1;
		}
		return;
	}

	if ((irq_vec & XAXIDMA_IRQ_IOC_MASK))   //completion
		Rx_Done = 1;
}

/*
 * Function:
 *     Make a DMA-IN transfer
 *  Inputs:
 *		pbuf	-- Store DMA-IN data
 *	Output:
 *		0		-- Success
 *		-1      -- Failed
 */
int RUN_DMA_IN(u8 *pbuf)
{
	int Status;

//	xil_printf("RUN_DMA_IN start...\r\n");
	Rx_Done = 0;
	Rx_Err = 0;

	Xil_DCacheFlushRange((UINTPTR)pbuf, BLOCK_SIZE); // Flush the Buffer
	Status = XAxiDma_SimpleTransfer(&AxiDma,(UINTPTR)pbuf, BLOCK_SIZE, XAXIDMA_DEVICE_TO_DMA);
	if (Status != XST_SUCCESS)
	{
		xil_printf("RUN_DMA_IN(): XAxiDma_SimpleTransfer not success\r\n");
		return -1;
	}
	Xil_Out32(XPAR_USR_HDL_0_S00_AXI_BASEADDR+0x001C,0x0001);  // tell usr_hdl to tx data

	while ((0==Rx_Done) && (Rx_Err==0)) ;  //Wait until RX done, or Error happens
	if (Rx_Err) {
		xil_printf("Rx_Err in dma_in_test, transmit%s done\r\n", Rx_Done? "":" not");
		return -1;
	}

//	xil_printf("RUN_DMA_IN end!\r\n");
	return 0;
}

/*
 * Function:
 *     Make a DMA-OUT transfer
 *  Inputs:
 *		pbuf	-- data to be DMA OUT
 *	Output:
 *		0		-- Success
 *		-1      -- Failed
 */
int RUN_DMA_OUT(u8 *pbuf)
{
	int Status;
//	xil_printf("RUN_DMA_OUT start...\r\n");

	Tx_Done = 0;
	Tx_Err = 0;

	Xil_DCacheFlushRange((UINTPTR)pbuf, BLOCK_SIZE); // Flush the Buffer
	Status = XAxiDma_SimpleTransfer(&AxiDma,(UINTPTR) pbuf, BLOCK_SIZE, XAXIDMA_DMA_TO_DEVICE);
	if (Status != XST_SUCCESS)
	{
		switch(Status)
		{
		case XST_FAILURE:
			xil_printf("RUN_DMA_OUT(): XAxiDma_SimpleTransfer not success, Status=XST_FAILURE\r\n");
			break;
		case XST_INVALID_PARAM:
			xil_printf("RUN_DMA_OUT(): XAxiDma_SimpleTransfer not success, Status=XST_INVALID_PARAM\r\n");
			break;
		default:
			xil_printf("RUN_DMA_OUT(): XAxiDma_SimpleTransfer not success. Status=%d\r\n",Status);
			break;
		}
		return -1;
	}

	while ((0==Tx_Done) && (Tx_Err==0)) ;  //Wait until TX done, or Error happens
	if (Tx_Err) {
		xil_printf("Tx_Err in dma_out_test, transmit%s done\r\n", Tx_Done? "":" not");
		return -1;
	}
	//xil_printf("RUN_DMA_OUT end!\r\n");
	return 0;
}

///////////////////////////////////////////////////////////////////////////////
// Init DMA CBF so that  ptr_write=ptr_read=0, and pbuf point to 4KB aligment
void init_dma_cbf(dma_cbf_struct *p_cbf)
{
	int i;
	p_cbf->ptr_read=0;
	p_cbf->ptr_write=0;
	p_cbf->pbuf=(u8*)((u32)(p_cbf->buf)&0xFFFFF000);
	p_cbf->pbuf+=BLOCK_SIZE;

	//
	dma_cbf.pbuf[0]=0xEB;
	dma_cbf.pbuf[1]=0x90;
	dma_cbf.pbuf[2]=0x00;
	dma_cbf.pbuf[3]=0x00;
	for(i=0;i<BLOCK_SIZE-4;i++)
		dma_cbf.pbuf[4+i]=i&0xFF;

	xil_printf("Init DMA CBF OK: addr of .buf=%X, addr of .pbuf=%X\r\n",p_cbf->buf, p_cbf->pbuf);
}


/*
 * Function:
 *     display buff data
 *  Inputs:
 *		buff	-- data buff
 *		size	-- bytes in buff to be display
 *		mode	-- 0 for all, 1 for only first line and last line
 */
void disp_buff(const u8 *buff, const int size, u8 mode)
{
	int i;
	u32 offset;

	if(mode==0) // display all
	{
		for (i=0; i<size; i+=4) {
			if( (i % 32) == 0 )
				xil_printf("%08X: %02X%02X%02X%02X", i, buff[i],buff[i+1],buff[i+2],buff[i+3]);
			else if ( (i % 32) == 28 )
				xil_printf(" %02X%02X%02X%02X\r\n", buff[i],buff[i+1],buff[i+2],buff[i+3]);
			else
				xil_printf(" %02X%02X%02X%02X", buff[i],buff[i+1],buff[i+2],buff[i+3]);
		}
	}
	else // display only first and last line
	{
		// first line
		xil_printf("%08X: ", 0);
		for(i=0;i<size;i+=4) {
			xil_printf(" %02X%02X%02X%02X", buff[i],buff[i+1],buff[i+2],buff[i+3]);
			if(i>=28)
			{	xil_printf("\r\n");
				break;
			}
		}

		if(size>64)
			xil_printf("...\r\n");
		else if(size<=32)
		{
			xil_printf("\r\n");
			return;
		}

		//last line
		offset=(size-1)&0xFFE0;
		xil_printf("%08X: ", offset);
		for(i=0;(offset+i)<size;i+=4)
		{
			xil_printf(" %02X%02X%02X%02X",
					buff[offset+i],
					buff[offset+i+1],
					buff[offset+i+2],
					buff[offset+i+3]);
			if(i>=28)
			{	xil_printf("\r\n");
				break;
			}
		}
	}
	xil_printf("\r\n");
}
