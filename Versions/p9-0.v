`timescale 1ps/1ps

//
// This is an inefficient implementation.
//   make it run correctly in less cycles, fastest implementation wins
//

//
// States:
//

// Fetch
`define F0 0
`define F2 2

`define S1 3

//dispatch
`define S0 20

// halt
`define HALT 15

module main();

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(1,main);
        $dumpvars(1,i0);
    end

    // clock
    wire clk;
    clock c0(clk);

    counter ctr((state == `HALT),clk,(state == `F0),cycle);

	reg[7:0]ldin = 0;
	reg[15:0]pc = 0;

reg fhalt = 0;


reg loading = 0;

//for loops
	reg[15:0]x = 0;
	reg[15:0]z = 1;	
	reg[7:0]y = 0;
	reg[15:0]i = 0;
	reg[15:0]j = 0;

	reg[7:0]w = 0;

	reg [15:0]a = 0;
	reg [15:0]b = 0;
	reg [15:0]c = 0;
	reg [15:0]d = 0;
	reg [15:0]e = 0;
	reg [15:0]g = 0;
	reg [15:0]h = 0;

	reg[15:0]f = 0;

	reg[3:0]dc = 0;

	//icache-direct mapping; mapping through last [4:0] instead of [15:11] since most instructions are linear
	reg[15:0]idata[0:31];
	reg[10:0]iaddress[0:31];
	reg[3:0]iinuse[0:31];
	reg iinCache = 0;

	reg [15:0]nextPc = 1;
	wire [4:0]set = pc[4:0];
	wire [10:0]offset = pc[15:5];

	reg [15:0] temprs = 10;
	reg [15:0] temp = 0;

	//dcache
	reg[9:0]daddress[0:3];
	reg[3:0]dinuse[0:3];
	reg[15:0]ddata[0:3];
	reg dinCache = 0;


	reg[15:0]ibuff =0;

	//halting inst buffer
	wire ihalt = rshalt || jeqhalt;
	reg rshalt = 0;
	reg jeqhalt = 0;

    reg [5:0]state = `F0;
  
    // regs
    reg [15:0]regs[0:15];
	reg rbusy[0:15];
	reg [7:0]rsrc[0:15];

	//rs ; 0-3 are ld, 4-7 are fxu
	reg rsbusy[0:7];
	reg [3:0]rsopcode[0:7];
	reg rsready0[0:7];
	reg [7:0]rssrc0[0:7];
	reg [15:0]rsval0[0:7];
	reg rsready1[0:7];
	reg [7:0]rssrc1[0:7];
	reg [15:0]rsval1[0:7];

	reg inrs = 0;
	reg [4:0] v =0;

	//initialization for caches, regs, rs
	initial begin
		for(v=0; v<4; v=v+1)begin
			dinuse[v] = 0;
			iinuse[v] = 0;
		end
		for(i=0; i<8; i = i+1) begin
				rsbusy[i] <= 0;
				rsopcode[i] <= 0;
				rsready0[i] <= 0;
				rssrc0[i] <= 0;
				rsval0[i] <= 16'hxxxx;
				rsready1[i] <= 0;
				rssrc1[i] <= 0;
				rsval1[i] <= 16'hxxxx;
		end
	end

	//instruction queue
	reg [15:0]iqueueData[0:4];
	reg [15:0]iqueuePc[0:4];

	//reorder buffer
	reg [15:0]robData[0:15];
	reg [15:0]robSrc[0:15];
	reg rob;

	//jmpcache
	reg [15:0]jmpSrc[0:3];
	reg [15:0]jmpPc[0:3];
	reg jmpUsed[0:3];
	reg [3:0]jmp=0;
	reg inJmp = 0;

	


    // fetch 
    wire [15:0]fetchOut;
    wire fetchReady;

    // load 
    wire [15:0]loadOut;
    wire loadReady;

    mem i0(clk,
       /* fetch port */
       (state == `F0),
       pc,
       fetchReady,
       fetchOut,

       /* load port */
       (z == 0),
       res,
       loadReady,
       loadOut


);

reg stop = 0;
    reg [15:0]res; // what to write in the register file

    always @(posedge clk) begin
		z <= 1;
		if(jmp != 3) begin
			jmp <= jmp +1;
		end else begin	
			jmp <=0;
		end

        case(state)
        `F0: begin
            state <= `F2;
        end
        `F2: begin
            if (fetchReady) begin
                	idata[set] = fetchOut;
					iaddress[set] = offset;
					iinuse[set] = 1;
					ibuff = fetchOut; 
            end
			if(!ihalt) begin
			//jump
				if(ibuff[15:12] == 2) begin
					for(h=0;h<4;h=h+1) begin
						if(jmpSrc[h] != pc && jmpUsed[h]==0 && !inJmp) begin
							jmpSrc[h] <= pc;
							jmpPc[h] <=ibuff[11:0];
							inJmp = 1;
						end
					end
					if(!inJmp) begin
						jmpSrc[jmp] <= pc;
						jmpPc[jmp] <=ibuff[11:0];
					end
					inJmp <=0;
					nextPc = ibuff[11:0];
			//halt
				end else if(ibuff[15:12] == 3) begin

					for(y = 4; y < 8; y=y+1) begin
						if(!inrs && rsbusy[y] == 0)  begin
							rsbusy[y] = 1;
							rsopcode[y] = 3;
							rsready0[y] =1;
							rsready1[y] =1;
							state <= `S1;
							inrs = 1;
						end
					end
					rshalt <= 1; 
					if (inrs == 1) begin	
						
						stop = 1;
					end
			//load
				end else if(ibuff[15:12] == 4) begin
					for(y = 0; y < 4; y=y+1) begin
						if(!inrs && rsbusy[y] == 0)  begin
							rsbusy[y] = 1;
							rsopcode[y] = ibuff[15:12];
							rsready0[y] = 1;
							rsval0[y] = ibuff[11:4];
							rsready1[y] = 1;
							rsval1[y] = ibuff[3:0];
							rbusy[ibuff[3:0]] = 1;
							rsrc[ibuff[3:0]] = y;

							inrs = 1;
							nextPc = pc+1;
						end
					end
			//ldr	
				end else if(ibuff[15:12] == 5) begin
					for(x=0; x < 4; x=x+1) begin
						if(temprs==10 && rsbusy[x]==0) begin
							temprs = x;
						end
					end
					if(temprs != 10) begin
						for(y = 4; y < 8; y=y+1) begin
							if(!inrs && rsbusy[y]==0)  begin
								rsbusy[y] = 1;
								rsopcode[y] = 1;
								if(!rbusy[ibuff[11:8]]) begin
									rsready0[y] = 1;
									rsval0[y] = regs[ibuff[11:8]];
								end else begin
									rsready0[y] = 0;
									rssrc0[y] = rsrc[ibuff[11:8]];
								end								
								if(!rbusy[ibuff[7:4]]) begin
									rsready1[y] = 1;
									rsval1[y] = regs[ibuff[7:4]];
								end else begin
									rsready1[y] = 0;
									rssrc1[y] = rsrc[ibuff[7:4]];
								end
								temp = y; 
								inrs = 1;
							end
						end
						if(inrs) begin
							rsbusy[temprs] = 1;
							rsopcode[temprs] = ibuff[15:12];
							rsready0[temprs] = 0;
							rssrc0[temprs] = temp;
							rsready1[temprs] = 1;
							rsval1[temprs] = ibuff[3:0];
							rbusy[ibuff[3:0]] = 1;
							rsrc[ibuff[3:0]] = temprs;
						end
					end
					if (inrs == 0 || temprs == 10) begin
						rshalt <= 1; 
					end else begin							
						nextPc = pc+1;
					end
					temprs <=10;
					temp <=0;
			//mov	
				end else if(ibuff[15:12] == 0) begin
					for(y = 4; y < 8; y=y+1) begin
						if(!inrs && rsbusy[y]==0)  begin
							rsbusy[y] = 1;
							rsopcode[y] = ibuff[15:12];
							rsready0[y] = 1;
							rsval0[y] = ibuff[11:4];
							rsready1[y] = 1;
							rsval1[y] = ibuff[3:0];
							rbusy[ibuff[3:0]] = 1;
							rsrc[ibuff[3:0]] = y;
							inrs = 1;
							nextPc = pc+1;
						end
					end
			//jeq
				end else if(ibuff[15:12] == 6) begin
					for(x=4; x < 8; x=x+1) begin
						if(temprs==10 && rsbusy[x]==0) begin
							temprs = x;
							rsbusy[x] = 1;
						end
					end
					if(temprs != 10) begin
						for(y = 4; y < 8; y=y+1) begin
							if(!inrs && rsbusy[y] ==0)  begin
								rsbusy[y] = 1;
								rsopcode[y] = 1;
								if(!rbusy[ibuff[11:8]]) begin
									rsready0[y] = 1;
									rsval0[y] = regs[ibuff[11:8]];
								end else begin
									rsready0[y] = 0;
									rssrc0[y] = rsrc[ibuff[11:8]];
									end								
									if(!rbusy[ibuff[7:4]]) begin
										rsready1[y] = 1;
										rsval1[y] = regs[ibuff[7:4]];
								end else begin
									rsready1[y] = 0;
									rssrc1[y] = rsrc[ibuff[7:4]];
								end
								inrs = 1;
								temp = y;
							end
						end
						if(inrs)  begin
							rsopcode[temprs] = 2;
							rsready0[temprs] = 0;
							rssrc0[temprs] = temp;
							rsready1[temprs] =1;
							rsval1[temprs] = ibuff[3:0];
							jeqhalt <= 1;
						end
					end
					if (inrs == 0) begin
						rsbusy[temprs] = 0; 
					end
					rshalt <= 1;
					temp <=0;
					temprs <= 10;
			//add		
				end else if(ibuff[15:12] == 1) begin
					for(y = 4; y < 8; y=y+1) begin
						if(!inrs && rsbusy[y]==0)  begin
							rsbusy[y] = 1;
							rsopcode[y] = ibuff[15:12];
							if(!rbusy[ibuff[11:8]]) begin
								rsready0[y] = 1;
								rsval0[y] = regs[ibuff[11:8]];
							end else begin
								rsready0[y] = 0;
								rssrc0[y] = rsrc[ibuff[11:8]];
							end								
							if(!rbusy[ibuff[7:4]]) begin
									rsready1[y] = 1;
								rsval1[y] = regs[ibuff[7:4]];
							end else begin
									rsready1[y] = 0;
								rssrc1[y] = rsrc[ibuff[7:4]];
							end
							rsrc[ibuff[3:0]] = y;
							rbusy[ibuff[3:0]] = 1; 
							inrs = 1;
							nextPc = pc+1;
						end
					end
				end

				for(g=0; g<4; g= g+1) begin
					if(nextPc == jmpSrc[g] && jmpUsed[g]==1) begin
						nextPc = jmpPc[g];
					end
				end

				pc <= nextPc;

				if(stop) begin

				end else if(iinuse[nextPc[4:0]] == 1 && iaddress[nextPc[4:0]] == nextPc[15:5]) begin
					ibuff <= idata[nextPc[4:0]];
				end else begin
					state <=`F0;
				end
				if(ibuff[15:12]==0 ||ibuff[15:12]==1 ||ibuff[15:12]==4) begin
					if(!inrs) begin
						rshalt <=1;
					end
				end
				inrs <=0;
			end	
		end
        `HALT: begin

        end
        `S1: begin

        end
        default: begin
            $display("unknown state %d",state);
            $finish;
        end
        endcase


	//fxu
	for(i = 4; i<8; i = i+1) begin
		if(rsbusy[i] == 1 && rsready0[i] == 1 && rsready1[i] ==1) begin
		//halt
			if(rsopcode[i] ==3) begin
				for(a=0; a<8; a=a+1) begin
					if(a!=i) begin
						if(rsbusy[a] == 1 || !stop ) begin
							fhalt = 1;
						end
					end
				end
				if (fhalt == 0) begin
					$display("#0:%x",regs[0]);
               		$display("#1:%x",regs[1]);
                	$display("#2:%x",regs[2]);
                	$display("#3:%x",regs[3]);
                	$display("#4:%x",regs[4]);
               		$display("#5:%x",regs[5]);
                	$display("#6:%x",regs[6]);
                	$display("#7:%x",regs[7]);
                	$display("#8:%x",regs[8]);
                	$display("#9:%x",regs[9]);
                	$display("#10:%x",regs[10]);
                	$display("#11:%x",regs[11]);
                	$display("#12:%x",regs[12]);
                	$display("#13:%x",regs[13]);
                	$display("#14:%x",regs[14]);
                	$display("#15:%x",regs[15]);
					state <= `HALT;
					rsbusy[i] <= 0;
				end
				fhalt<=0;
//mov
			end else if(rsopcode[i] == 0) begin
				for(a=0; a<8; a=a+1) begin
					if(a!=i) begin
						if(rssrc0[a] == i && rsready0[a]==0 && rsbusy[a]) begin
							rsready0[a] <= 1;
							rsval0[a] <= rsval0[i];
						end
						if(rssrc1[a] == i && rsready1[a]==0) begin
							rsready1[a] <= 1;
							rsval1[a] <= rsval0[i];
						end
					end
				end
				for(b=0; b<16; b=b+1) begin
					if(rsrc[b] == i && rbusy[b] == 1) begin
						rbusy[b] <= 0;
						regs[b] <= rsval0[i];
						rsrc[b] <=0;
					end
				end
				rshalt<=0;
				rsbusy[i] <= 0;
				rsopcode[i] <= 0;
				rsready0[i] <= 0;
				rssrc0[i] <= 0;
				rsval0[i] <= 16'hxxxx;
				rsready1[i] <= 0;
				rssrc1[i] <= 16'hxxxx;
				rsval1[i] <= 16'hxxxx;
//add

			end else if(rsopcode[i] == 1) begin
				for(a=0; a<8; a=a+1) begin
					if(a!=i) begin
						if(rssrc0[a] == i && rsready0[a]==0) begin
							if(rsopcode[a]==2) begin
								rsval0[a] <= (rsval0[i] == rsval1[i]) ? 1 : 0;
							end else begin
								rsval0[a] <= rsval0[i]+rsval1[i];
							end
							rsready0[a] <= 1;
						end
						if(rssrc1[a] == i  &&rsready1[a]==0) begin
							rsready1[a] <= 1;
							rsval1[a] <= rsval0[i]+rsval1[i];
						end
					end
				end
				for(b=0; b<16; b=b+1) begin
					if(rsrc[b] == i && rbusy[b]==1) begin
						rbusy[b] <= 0;
						rsrc[b] <= 0;
						regs[b] <= rsval0[i]+rsval1[i];
					end
				end
				rshalt <=0;
				rsbusy[i] <= 0;
				rsopcode[i] <= 0;
				rsready0[i] <= 0;
				rssrc0[i] <= 0;
				rsval0[i] <= 16'hxxxx;
				rsready1[i] <= 0;
				rssrc1[i] <= 0;
				rsval1[i] <= 16'hxxxx;
//jeq
			end else if(rsopcode[i] == 2) begin
				if (rsval0[i] == 1) begin
					nextPc= pc+rsval1[i];
				end else begin
					nextPc= pc+1;
				end

				pc <= nextPc;
				if(iinuse[nextPc[4:0]] == 1 && iaddress[nextPc[4:0]] == nextPc[15:5]) begin
					ibuff <= idata[nextPc[4:0]];
				end else begin
					state <=`F0;
				end

				jeqhalt <= 0;
				rshalt <= 0;
				rsbusy[i] <= 0;
				rsopcode[i] <= 0;
				rsready0[i] <= 0;
				rssrc0[i] <= 16'hxxxx;
				rsval0[i] <= 16'hxxxx;
				rsready1[i] <= 0;
				rssrc1[i] <= 16'hxxxx;
				rsval1[i] <= 16'hxxxx;
			end
		end
	end


	//load unit
		for(j=0; j<4; j=j+1) begin
			if(rsbusy[j] == 1 && rsready0[j] == 1) begin
				for (c = 0; c < 4; c = c + 1) begin
   	  				if(dinuse[c] == 1 && !dinCache) begin 
						if(daddress[c] == rsval0[j]) begin
							for(x=0; x<8; x=x+1) begin
								if(rssrc0[x] == j && rsready0[x]==0) begin
									rsready0[x] <= 1;
									rsval0[x] <= ddata[c];
								end
								if(rssrc1[x] == j && rsready1[x]==0) begin
									rsready1[x] <= 1;
									rsval1[x] <= ddata[c];
								end
							end
							for(w=0; w<16; w=w+1) begin
								if(rsrc[w] == j && rbusy[w]==1) begin
									rbusy[w] <= 0;
									regs[w] <= ddata[c];
								end
							end

							rshalt <=0;
							rsbusy[j] <= 0;
							rsopcode[j] <= 0;
							rsready0[j] <= 0;
							rssrc0[j] <= 16'hxxxx;
							rsval0[j] <= 16'hxxxx;
							rsready1[j] <= 0;
							rssrc1[j] <= 16'hxxxx;
							rsval1[j] <= 16'hxxxx;
							dinCache = 1;
						end
					end
				end
				if(dinCache == 0 && loading == 0) begin
					res <= rsval0[j];
					z <= 0;
					loading <= 1;
				end
				dinCache = 0;
			end
		end

        if (loadReady) begin 
			loading <= 0;
						
		//loop for checking dcache				
			for (w = 0; w < 4; w = w +1) begin
   	  			if(dinuse[w]==0) begin 
					dinuse[w]<=1;
					daddress[w] <= res;
					ddata[w] <= loadOut;
					dinCache = 1;
				end
			end
			if(dinCache == 0) begin
			//FIFO
				if(dc < 3) begin
					dc <= dc +1;
				end else begin
					dc <= 0;
				end
				daddress[dc] <= res;
				ddata[dc] <= loadOut;		
			end
			dinCache <= 0;
        end


    end

endmodule

