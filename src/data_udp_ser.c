#include <stdio.h>
#include <string.h>
#include "sleep.h"
#include "lwip/err.h"
#include "lwip/udp.h"
#include "xil_printf.h"
#include "hw_misc.h"
#include "data_udp_ser.h"

#define DATA_UDP_SER_PORT  1002

u32 udp_rx_bytes_count;
u32 udp_tx_bytes_count;
u8  udp_path=0x03;

static u8 usr_udp_buf[BLOCK_SIZE*2];
static u8 *p_usr_udp_buf;
struct pbuf * tx_pbuf;

// from main.c
extern void print_ip(char *msg, struct ip_addr *ip, char *end);

u8 check_UDP_usr_head(u8 *p, u8 index)
{
	if((p[0]==0xEB) && (p[1]==0x91))
	{
		if(index!=0)
			xil_printf("Warning: UDP usr head not match, index=%d, expect 0, manually sync!\r\n", index);
		return 1;
	}
	else
		return 0;
}

void dus_recv_callback(void* arg,struct udp_pcb* upcb,struct pbuf* p,struct ip_addr*addr ,u16_t port)
{
	err_t rt;
	static u16 last_port=0;
	static u8 seg_cnt=0;
	int ret;
	u8 i;

	if(last_port!=port)
	{ // if port changed, it mush be a new client send UDP packet to here.
		xil_printf("---------------------------------------------------------------\r\n");
		print_ip("Start new UDP loop transfer from remote IP=",addr,"");
		xil_printf(" port=%d\r\n",port);
		last_port=port;
		udp_rx_bytes_count=0;
		udp_tx_bytes_count=0;
		seg_cnt=0;

		// following to set p_usr_udp_buf point to the first 4KB alignent address of usr_udp_buf, which needed by AXI DMA with PL
		p_usr_udp_buf=(u8*)((u32)(usr_udp_buf)&0xFFFFF000);
		p_usr_udp_buf+=BLOCK_SIZE;
		xil_printf("Init Usr UDP BUF OK: addr of usr_udp_buf=%X, addr of p_usr_udp_buf=%X\r\n",usr_udp_buf,p_usr_udp_buf);
	}

	if(p->tot_len!=1024)
		xil_printf("UDP received a packet with tot_len=%d, not 1024\r\n", p->tot_len);

	udp_rx_bytes_count+=p->tot_len;

//	xil_printf("seg_cnt=%d, p->tot_len=%d\n",seg_cnt, p->tot_len);
	if(check_UDP_usr_head(p->payload, seg_cnt))
		seg_cnt=0;

	pbuf_copy_partial(p,p_usr_udp_buf+seg_cnt*1024, p->tot_len, 0);

	if(seg_cnt==3)  // already received 4-segment (= 1 block size), then Remote->PS->PL->PS->Remote or Remote->PS->Remote
	{
		if(udp_path==0x13)  // path 13: Remote->PS->PL->PS->Remote
		{
			ret=RUN_DMA_OUT(p_usr_udp_buf);  //Make a DMA: PS->PL
			if(ret)
				xil_printf("Error: RUN_DMA_OUT Failed in DATA UDP!\r\n");

			write_pl_reg(0x0018,0x00000003);  //force usr_pl to copy Tx_RAM to RxRAM

			ret=RUN_DMA_IN(p_usr_udp_buf);  //Make a DMA: PL->PS
			if(ret)
				xil_printf("Error: RUN_DMA_IN Failed in DATA UDP!\r\n");
		}

		for(i=0;i<4;i++)
		{
			tx_pbuf = pbuf_alloc(PBUF_TRANSPORT, 1024, PBUF_REF);
			tx_pbuf->payload=p_usr_udp_buf+1024*i;
			rt=udp_sendto(upcb, tx_pbuf, addr, port);
			if(rt!=ERR_OK)
				xil_printf("error: udp_sendto error, rt=%d\r\n",rt);
			else
				udp_tx_bytes_count+=p->tot_len;
			pbuf_free(tx_pbuf);
		}
	}

	seg_cnt++;
	if(seg_cnt>=4)
		seg_cnt=0;
	pbuf_free(p);
}

int start_data_udp_ser()
{
	struct udp_pcb *pcb;
	err_t err;
	unsigned port = DATA_UDP_SER_PORT;

	/* create new UDP PCB structure */
	pcb = udp_new();
	if (!pcb) {
		xil_printf("Error creating UDP PCB. Out of Memory\r\n");
		return -1;
	}

	/* bind to specified @port */
	err = udp_bind(pcb, IP_ADDR_ANY, port);
	if (err != ERR_OK) {
		xil_printf("Unable to bind to UDP port %d: err = %d\r\n", port, err);
		udp_remove(pcb);
		return -2;
	}

    udp_recv(pcb, dus_recv_callback, NULL);
	xil_printf("DATA UDP server started @ port %d\r\n", port);

	return 0;
}
