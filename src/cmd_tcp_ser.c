#include <stdio.h>
#include <string.h>
#include "xil_types.h"
#include "xil_printf.h"
#include "lwip/err.h"
#include "lwip/tcp.h"
#include "hw_misc.h"
#include "cmd_tcp_ser.h"

#define LAST_DATE 0x20181112

// from hw_misc.c
extern u8 led_blink_mode;

// from data_tcp_ser.c
extern u32 tcp_rx_bytes_count;
extern u32 tcp_tx_bytes_count;
extern u8  tcp_path;

// from data_udp_ser.c
extern u32 udp_rx_bytes_count;
extern u32 udp_tx_bytes_count;
extern u8  udp_path;

static u8 rpl_buf[10];

void fill_rpl_buf(u8 is_write, u16 addr, u32 data)
{
	rpl_buf[0]=0xEB;
	rpl_buf[1]=is_write ? 0x90 : 0x91;
	rpl_buf[2]=(addr>>8)&0xFF;
	rpl_buf[3]=addr&0xFF;
	rpl_buf[4]=(data>>24)&0xFF;
	rpl_buf[5]=(data>>16)&0xFF;
	rpl_buf[6]=(data>>8)&0xFF;
	rpl_buf[7]=data&0xFF;
	rpl_buf[8]=0xEE;
	rpl_buf[9]=0xEE;
}

static void decode_and_rsp_remote_cmd(struct tcp_pcb *tpcb, struct pbuf *p)
{
	u8 *pbuf;
	u16 reg_addr;
	u32 reg_data;
	int ret;
	int i;

	pbuf=(u8*)p->payload;

	// Decode write cmd (TYPE=EB90)
	if((pbuf[0]==0xEB)&&(pbuf[1]==0x90)&&(pbuf[8]==0xEE)&&(pbuf[9]==0xEE))
	{
		reg_addr=(pbuf[2]<<8)|pbuf[3];
		reg_data=(pbuf[4]<<24)|(pbuf[5]<<16)|(pbuf[6]<<8)|pbuf[7];

		fill_rpl_buf(1, reg_addr, reg_data);
		switch(reg_addr)
		{
		case 0x8004:
			led_blink_mode=reg_data&0x3;
			break;
		case 0x8010:
			tcp_path=reg_data&0xFF;
			break;
		case 0x801C:
			if(reg_data&0x00000001)
			{
				tcp_rx_bytes_count=0;
				tcp_tx_bytes_count=0;
				init_dma_cbf(&dma_cbf);
			}
			break;
		case 0x8020:
			udp_path=reg_data&0xFF;
			break;
		case 0x802C:
			if(reg_data&0x00000001)
			{
				udp_rx_bytes_count=0;
				udp_tx_bytes_count=0;
			}
			break;

		case 0x8030: // Single DMA_IN test
			memset(dma_cbf.pbuf,0x55,BLOCK_SIZE);
			ret=RUN_DMA_IN(dma_cbf.pbuf);
			if(ret==0)
			{
				xil_printf("Following is the data which DMA IN from PL:\r\n");
				disp_buff(dma_cbf.pbuf,BLOCK_SIZE,0);
				xil_printf("RUN_DMA_IN done!\r\n");
			}
			break;
		case 0x8034: // Single DMA_OUT test
			for(i=0;i<BLOCK_SIZE/4;i++)
				((u32*)dma_cbf.pbuf)[i]=reg_data;
			ret=RUN_DMA_OUT(dma_cbf.pbuf);
			if(ret==0)
				xil_printf("RUN_DMA_OUT done!\r\n");
			break;

		default:
			if((reg_addr<0x0400) && ((reg_addr&0x03)==0))  // only address 0x0000-0x03FC with 4-byte aligment can map to PL (USR_HDL)
				write_pl_reg(reg_addr,reg_data);
			else
				fill_rpl_buf(1,0xEEEE,0xEEEEEEEE);  // tell pc it is a invalid command

			break;
		}
	}

	// Decode read cmd (TYPE=91)
	if((pbuf[0]==0xEB)&&(pbuf[1]==0x91)&&(pbuf[8]==0xEE)&&(pbuf[9]==0xEE))
	{
		reg_addr=(pbuf[2]<<8)|pbuf[3];

		switch(reg_addr)
		{
		case 0x8000:  // read fixed
			fill_rpl_buf(0, reg_addr, LAST_DATE);
			break;
		case 0x8004:
			fill_rpl_buf(0, reg_addr, led_blink_mode);
			break;
		case 0x8010:
			fill_rpl_buf(0, reg_addr, tcp_path);
			break;
		case 0x8014:
			fill_rpl_buf(0, reg_addr, tcp_rx_bytes_count);
			break;
		case 0x8018:
			fill_rpl_buf(0, reg_addr, tcp_tx_bytes_count);
			break;
		case 0x8020:
			fill_rpl_buf(0, reg_addr, udp_path);
			break;
		case 0x8024:
			fill_rpl_buf(0, reg_addr, udp_rx_bytes_count);
			break;
		case 0x8028:
			fill_rpl_buf(0, reg_addr, udp_tx_bytes_count);
			break;
		default:
			if((reg_addr<0x0400) && ((reg_addr&0x03)==0))  // only address 0x0000-0x03FC with 4-byte aligment can map to PL (USR_HDL)
			{
				reg_data=read_pl_reg(reg_addr);
				fill_rpl_buf(0,reg_addr,reg_data);
			}
			else
				fill_rpl_buf(0,0xEEEE,0xEEEEEEEE);

			break;
		}
	}

	// Give reply
	if(tcp_sndbuf(tpcb) > 10)
		tcp_write(tpcb, rpl_buf, 10, 1);
	else
		xil_printf("cts: no space in tcp_sndbuf\r\n");
}


static err_t cts_recv_callback(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err)
{
	/* do not read the packet if we are not in ESTABLISHED state */
	if (!p) {
		tcp_close(tpcb);
		tcp_recv(tpcb, NULL);
		return ERR_OK;
	}

	// indicate that the packet has been received
	tcp_recved(tpcb, p->tot_len);

	// decode the cmd and give rsp
	decode_and_rsp_remote_cmd(tpcb, p);

	// free the received pbuf
	pbuf_free(p);

	return ERR_OK;
}

static err_t cts_accept_callback(void *arg, struct tcp_pcb *newpcb, err_t err)
{
	static int connection = 0;
	u32 remote;
	/* set the receive callback for this connection */
	tcp_recv(newpcb, cts_recv_callback);

	/* just use an integer number indicating the connection id as the
	   callback argument */
	tcp_arg(newpcb, (void*)(UINTPTR)connection);
	remote=newpcb->remote_ip.addr;
	xil_printf("CMD TCP server accepted %d-th connection from remote ip=%d.%d.%d.%d port=%d\r\n",
			connection,
			remote&0xff, (remote>>8)&0xff, (remote>>16)&0xff, (remote>>24)&0xff,
			newpcb->remote_port
			);

	/* increment for subsequent accepted connections */
	connection++;

	return ERR_OK;
}


#define CMD_TCP_SER_PORT  1000
int start_cmd_tcp_ser()
{
	struct tcp_pcb *pcb;
	err_t err;
	unsigned port = CMD_TCP_SER_PORT;

	/* create new TCP PCB structure */
	pcb = tcp_new();
	if (!pcb) {
		xil_printf("Error creating PCB. Out of Memory\r\n");
		return -1;
	}

	/* bind to specified @port */
	err = tcp_bind(pcb, IP_ADDR_ANY, port);
	if (err != ERR_OK) {
		xil_printf("Unable to bind to port %d: err = %d\r\n", port, err);
		return -2;
	}

	/* we do not need any arguments to callback functions */
	tcp_arg(pcb, NULL);

	/* listen for connections */
	pcb = tcp_listen(pcb);
	if (!pcb) {
		xil_printf("Out of memory while tcp_listen\r\n");
		return -3;
	}

	/* specify callback to use for incoming connections */
	tcp_accept(pcb, cts_accept_callback);

	xil_printf("CMD TCP server started @ port %d\r\n", port);

	return 0;
}

