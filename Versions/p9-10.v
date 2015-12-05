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
`define F1 1

`define S1 3

//dispatch
`define S0 2

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

reg ddinCache = 0;

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
reg[15:0]l=0;

reg[15:0]t = 0;

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

	reg [15:0] temprs = 12;
	reg [15:0] temp = 0;

	//dcache
	reg[9:0]daddress[0:3];
	reg[3:0]dinuse[0:3];
	reg[15:0]ddata[0:3];
	reg dinCache = 0;

	//instruction buffer
	reg [3:0]iFull = 0;
	reg [15:0]iPc[0:1];
	reg iValid[0:1];
	reg[15:0]ibuff[0:1];

	//halting inst buffer
	wire ihalt = rshalt || jeqhalt;
	reg rshalt = 0;
	reg jeqhalt = 0;

    reg [5:0]state = `F0;

	//actual regs
    reg [15:0]regs[0:15];
	reg rbusy[0:15];
	reg [7:0]rsrc[0:15];	
  
	//rs ; 0-3 are ld, 4-7 are fxu, 8-10 are jeq, 11 is halt
	reg rsbusy[0:11];
	reg [3:0]rsopcode[0:11];
	reg rsready0[0:11];
	reg [7:0]rssrc0[0:11];
	reg [15:0]rsval0[0:11];
	reg rsready1[0:11];
	reg [7:0]rssrc1[0:11];
	reg [15:0]rsval1[0:11];
	reg [15:0]rsrob[0:11];

reg[15:0]ii=0;

	reg inrs = 0;
	reg [4:0] v =0;

	//initialization for caches, regs, rs
	initial begin
		for(v=0; v<4; v=v+1)begin
			iValid[v] = 0;
			dinuse[v] = 0;
			iinuse[v] = 0;
		end
		for(ii=0; ii<12; ii = ii+1) begin
				rsrob[ii] = 16'hxxxx;
				rsbusy[ii] = 0;
				rsopcode[ii] = 0;
				rsready0[ii] = 0;
				rssrc0[ii] = 0;
				rsval0[ii] = 16'hxxxx;
				rsready1[ii] = 0;
				rssrc1[ii] = 0;
				rsval1[ii] = 16'hxxxx;
		end
	end

//reorder buffer
	reg robValid[0:15];
	reg [15:0]robData[0:15];
	reg [15:0]robSrc[0:15];
	reg [3:0]robOpcode[0:15];
	reg robFinish[0:15];
	reg [15:0]robPc[0:15];
	reg [3:0]robHPt = 0;
	reg [3:0]robTPt = 0;


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
reg[15:0]flush=0;
reg stop = 0;

reg[15:0]test = 0;

	wire instrDep = (ibuff[1][11:8] != ibuff[0][3:0] && ibuff[1][7:4] != ibuff[0][3:0] && ibuff[0][15:12]!=2);
	wire instrFxu0 = (ibuff[0][15:12] == 0 || ibuff[0][15:12] == 1 || ibuff[0][15:12] == 5 || ibuff[0][15:12] == 6);
	wire instrLd0 = (ibuff[0][15:12] == 4 || ibuff[0][15:12] == 5);
	wire instrFxu1 = (ibuff[1][15:12] == 0 || ibuff[1][15:12] == 1 || ibuff[1][15:12] == 5 || ibuff[1][15:12] == 6);
	wire instrLd1 = (ibuff[1][15:12] == 4 || ibuff[1][15:12] == 5);

	reg [15:0]fxu0 = 12;
	reg [15:0]load0 = 12;
	reg [15:0]fxu1 = 12;
	reg [15:0]load1 = 12;

	reg valid0 = 0;
	reg valid1 = 0;



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
            state <= `F1;
        end
        `F1: begin
			  if (fetchReady) begin
               	idata[set] = fetchOut;
				iaddress[set] = offset;
				iinuse[set] = 1; 
            end

			if(iinuse[set] == 1 && iaddress[set]==offset) begin
			//checking jmp 
				if(idata[set][15:12]==2) begin
					pc <= idata[set][11:0];
				end else begin
					iValid[iFull] = 1;
					iPc[iFull] = pc;
					ibuff[iFull] = idata[set];
					iFull = iFull + 1;
					if(iFull == 2) begin
						state <=`S0;
					end
					pc <= pc+1;
				end
			end else begin
				state <= `F0;
			end
		end
		`S0: begin

			if(!ihalt) begin

			//gettin rs for 1st instr
				if(instrFxu0) begin
					for(x=4; x<8; x=x+1) begin
						if(!rsbusy[x] && fxu0==12) begin
							fxu0 = x;
							rsbusy[x] =1;
						end
					end	
				end
				if(instrLd0) begin
					for(y=0; y<4; y=y+1) begin
						if(!rsbusy[y] && load0==12) begin
							load0 = y;
							rsbusy[y] =1;
						end
					end
				end

			//gettin rs for 2nd instr
				if(instrFxu1 && instrDep) begin
					for(a=4; a<8; a=a+1) begin
						if(!rsbusy[a] && fxu1==12) begin
							fxu1 = a;
							rsbusy[a] =1;
						end
					end	
				end
				if(instrLd1 && instrDep) begin
					for(b=0; b<4; b=b+1) begin
						if(!rsbusy[b] && load1==12) begin
							load1 = b;
							rsbusy[b] =1;
						end
					end
				end

//1st instr
			//halt
				if(ibuff[0][15:12] == 3) begin
					if(rsbusy[11] == 0)  begin
						rsbusy[11] = 1;
						rsrob[11] = robTPt;
						rsopcode[11] = 3;
						rsready0[11] =1;
						rsready1[11] =1;
						state <= `S1;
						valid0 = 1;
						stop = 1; 

						robOpcode[robTPt] = ibuff[0][15:12];
						robValid[robTPt] = 1;
						robSrc[robTPt] = 11;
						robFinish[robTPt] = 1;
						robPc[robTPt] = iPc[0];
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end
			//load
				end else if(ibuff[0][15:12] == 4) begin
					if(load0!=12)  begin
						rsrob[load0] = robTPt;
						rsbusy[load0] = 1;
						rsopcode[load0] = ibuff[0][15:12];
						rsready0[load0] = 1;
						rsval0[load0] = ibuff[0][11:4];
						rsready1[load0] = 1;
						rsval1[load0] = ibuff[0][3:0];
						rbusy[ibuff[0][3:0]] = 1;
						rsrc[ibuff[0][3:0]] = load0;
						valid0 = 1;

						robOpcode[robTPt] = ibuff[0][15:12];
						robValid[robTPt] = 1;
						robSrc[robTPt] = load0;
						robFinish[robTPt] = 0;
						robPc[robTPt] = iPc[0];
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end
			//ldr	
				end else if(ibuff[0][15:12] == 5) begin
					if(load0 !=12 && fxu0 !=12)  begin
						rsrob[fxu0] = robTPt;
						rsbusy[fxu0] = 1;
						rsopcode[fxu0] = 1;
						if(!rbusy[ibuff[0][11:8]]) begin
							rsready0[fxu0] = 1;
							rsval0[fxu0] = regs[ibuff[0][11:8]];
						end else begin
							rsready0[fxu0] = 0;
							rssrc0[fxu0] = rsrc[ibuff[0][11:8]];
						end								
						if(!rbusy[ibuff[0][7:4]]) begin
							rsready1[fxu0] = 1;
							rsval1[fxu0] = regs[ibuff[0][7:4]];
						end else begin
							rsready1[fxu0] = 0;
							rssrc1[fxu0] = rsrc[ibuff[0][7:4]];
						end 
						valid0 = 1;

						robSrc[robTPt] = fxu0;
						robValid[robTPt] = 1;
						robOpcode[robTPt] = 1;
						robPc[robTPt] = iPc[0];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	

						rsrob[load0] = robTPt;
						rsbusy[load0] = 1;
						rsopcode[load0] = 4;
						rsready0[load0] = 0;
						rssrc0[load0] = fxu0;
						rsready1[load0] = 1;
						rsval1[load0] = ibuff[0][3:0];

						rbusy[ibuff[0][3:0]] = 1;
						rsrc[ibuff[0][3:0]] = load0;

						robOpcode[robTPt] = 4;
						robValid[robTPt] = 1;
						robSrc[robTPt] = load0;
						robFinish[robTPt] = 0;
						robPc[robTPt] = iPc[0];
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end else begin
						rsbusy[fxu0] = 0;
						rsbusy[load0] = 0;
					end
			//mov	
				end else if(ibuff[0][15:12] == 0) begin
					if(fxu0 !=12)  begin
						rsrob[fxu0] = robTPt;
						rsbusy[fxu0] = 1;
						rsopcode[fxu0] = ibuff[0][15:12];
						rsready0[fxu0] = 1;
						rsval0[fxu0] = ibuff[0][11:4];
						rsready1[fxu0] = 1;
						rsval1[fxu0] = ibuff[0][3:0];
						rbusy[ibuff[0][3:0]] = 1;
						rsrc[ibuff[0][3:0]] = fxu0;
						valid0 = 1;

						robSrc[robTPt] = fxu0;
						robValid[robTPt] = 1;
						robOpcode[robTPt] = ibuff[0][15:12];
						robPc[robTPt] = iPc[0];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end
			//jeq
				end else if(ibuff[0][15:12] == 6) begin
					if(fxu0 != 12 && !rsbusy[8]) begin
						rsrob[fxu0] = robTPt;
						rsbusy[fxu0] = 1;
						rsopcode[fxu0] = 7;
						if(!rbusy[ibuff[0][11:8]]) begin
							rsready0[fxu0] = 1;
							rsval0[fxu0] = regs[ibuff[0][11:8]];
						end else begin
							rsready0[fxu0] = 0;
							rssrc0[fxu0] = rsrc[ibuff[0][11:8]];
						end								
						if(!rbusy[ibuff[0][7:4]]) begin
							rsready1[fxu0] = 1;
							rsval1[fxu0] = regs[ibuff[0][7:4]];
						end else begin
							rsready1[fxu0] = 0;
							rssrc1[fxu0] = rsrc[ibuff[0][7:4]];
						end
						valid0 = 1;

						robSrc[robTPt] = fxu0;
						robValid[robTPt] = 1;
						robOpcode[robTPt] = 7;
						robPc[robTPt] = iPc[0];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	

						rsbusy[8] = 1;
						rsrob[8] = robTPt;
						rsopcode[8] = ibuff[0][15:12];
						rsready0[8] = 0;
						rssrc0[8] = fxu0;
						rsready1[8] =1;
						rsval1[8] = ibuff[0][3:0];

						robSrc[robTPt] = 8;
						robValid[robTPt] = 1;
						robOpcode[robTPt] = ibuff[0][15:12];
						robPc[robTPt] = iPc[0];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end else begin
						rsbusy[fxu0] =0;
					end
			//add		
				end else if(ibuff[0][15:12] == 1) begin
					if(fxu0!=12) begin
						rsrob[fxu0] = robTPt;
						rsbusy[fxu0] = 1;
						rsopcode[fxu0] = ibuff[0][15:12];
						if(!rbusy[ibuff[0][11:8]]) begin
							rsready0[fxu0] = 1;
							rsval0[fxu0] = regs[ibuff[0][11:8]];
						end else begin
							rsready0[fxu0] = 0;
							rssrc0[fxu0] = rsrc[ibuff[0][11:8]];
						end								
						if(!rbusy[ibuff[0][7:4]]) begin
							rsready1[fxu0] = 1;
							rsval1[fxu0] = regs[ibuff[0][7:4]];
						end else begin
							rsready1[fxu0] = 0;
							rssrc1[fxu0] = rsrc[ibuff[0][7:4]];
						end
						rsrc[ibuff[0][3:0]] = fxu0;
						rbusy[ibuff[0][3:0]] = 1; 
						valid0 = 1;

						robSrc[robTPt] = fxu0;
						robValid[robTPt] = 1;
						robOpcode[robTPt] = ibuff[0][15:12];
						robPc[robTPt] = iPc[0];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end
				end

//2nd instr
if(valid0) begin
			//halt
				if(ibuff[1][15:12] == 3) begin
					if(rsbusy[11] == 0)  begin
						rsbusy[11] = 1;
						rsrob[11] = robTPt;
						rsopcode[11] = 3;
						rsready0[11] =1;
						rsready1[11] =1;
						state <= `S1;
						valid1 = 1;
						stop = 1;

						robOpcode[robTPt] = ibuff[1][15:12];
						robValid[robTPt] = 1;
						robSrc[robTPt] = 11;
						robFinish[robTPt] = 1;
						robPc[robTPt] = iPc[1];
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end
			//load
				end else if(ibuff[1][15:12] == 4) begin
					if(load1!=12)  begin
						rsrob[load1] = robTPt;
						rsbusy[load1] = 1;
						rsopcode[load1] = ibuff[1][15:12];
						rsready0[load1] = 1;
						rsval0[load1] = ibuff[1][11:4];
						rsready1[load1] = 1;
						rsval1[load1] = ibuff[1][3:0];
						rbusy[ibuff[1][3:0]] = 1;
						rsrc[ibuff[1][3:0]] = load1;
						valid1 = 1;

						robOpcode[robTPt] = ibuff[1][15:12];
						robValid[robTPt] = 1;
						robSrc[robTPt] = load1;
						robFinish[robTPt] = 0;
						robPc[robTPt] = iPc[1];
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end
			//ldr	
				end else if(ibuff[1][15:12] == 5) begin
					if(load1 !=12 && fxu1 !=12)  begin
						rsrob[fxu1] = robTPt;
						rsbusy[fxu1] = 1;
						rsopcode[fxu1] = 1;
						if(!rbusy[ibuff[1][11:8]]) begin
							rsready0[fxu1] = 1;
							rsval0[fxu1] = regs[ibuff[1][11:8]];
						end else begin
							rsready0[fxu1] = 0;
							rssrc0[fxu1] = rsrc[ibuff[1][11:8]];
						end								
						if(!rbusy[ibuff[1][7:4]]) begin
							rsready1[fxu1] = 1;
							rsval1[fxu1] = regs[ibuff[1][7:4]];
						end else begin
							rsready1[fxu1] = 0;
							rssrc1[fxu1] = rsrc[ibuff[1][7:4]];
						end 
						valid1 = 1;

						robSrc[robTPt] = fxu1;
						robValid[robTPt] = 1;
						robOpcode[robTPt] = 1;
						robPc[robTPt] = iPc[1];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	

						rsrob[load1] = robTPt;
						rsbusy[load1] = 1;
						rsopcode[load1] = 4;
						rsready0[load1] = 0;
						rssrc0[load1] = fxu1;
						rsready1[load1] = 1;
						rsval1[load1] = ibuff[1][3:0];

						rbusy[ibuff[1][3:0]] = 1;
						rsrc[ibuff[1][3:0]] = load1;

						robOpcode[robTPt] = 4;
						robValid[robTPt] = 1;
						robSrc[robTPt] = load1;
						robFinish[robTPt] = 0;
						robPc[robTPt] = iPc[1];
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end
					end else begin
						rsbusy[fxu1] = 0;
						rsbusy[load1] = 0;
					end
			//mov	
				end else if(ibuff[1][15:12] == 0) begin
					if(fxu1 !=12)  begin
						rsrob[fxu1] = robTPt;
						rsbusy[fxu1] = 1;
						rsopcode[fxu1] = ibuff[1][15:12];
						rsready0[fxu1] = 1;
						rsval0[fxu1] = ibuff[1][11:4];
						rsready1[fxu1] = 1;
						rsval1[fxu1] = ibuff[1][3:0];
						rbusy[ibuff[1][3:0]] = 1;
						rsrc[ibuff[1][3:0]] = fxu1;
						valid1 = 1;

						robSrc[robTPt] = fxu1;
						robValid[robTPt] = 1;
						robOpcode[robTPt] = ibuff[1][15:12];
						robPc[robTPt] = iPc[1];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end
			//jeq
				end else if(ibuff[1][15:12] == 6) begin
					if(fxu1 != 12 && !rsbusy[8]) begin
						rsrob[fxu1] = robTPt;
						rsbusy[fxu1] = 1;
						rsopcode[fxu1] = 7;
						if(!rbusy[ibuff[1][11:8]]) begin
							rsready0[fxu1] = 1;
							rsval0[fxu1] = regs[ibuff[1][11:8]];
						end else begin
							rsready0[fxu1] = 0;
							rssrc0[fxu1] = rsrc[ibuff[1][11:8]];
						end								
						if(!rbusy[ibuff[1][7:4]]) begin
							rsready1[fxu1] = 1;
							rsval1[fxu1] = regs[ibuff[1][7:4]];
						end else begin
							rsready1[fxu1] = 0;
							rssrc1[fxu1] = rsrc[ibuff[1][7:4]];
						end
						valid1 = 1;

						robSrc[robTPt] = fxu1;
						robValid[robTPt] = 1;
						robOpcode[robTPt] = 7;
						robPc[robTPt] = iPc[1];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	

						rsbusy[8] = 1;
						rsrob[8] = robTPt;
						rsopcode[8] = ibuff[1][15:12];
						rsready0[8] = 0;
						rssrc0[8] = fxu1;
						rsready1[8] =1;
						rsval1[8] = ibuff[1][3:0];

						robSrc[robTPt] = 8;
						robValid[robTPt] = 1;
						robOpcode[robTPt] = ibuff[1][15:12];
						robPc[robTPt] = iPc[1];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end else begin
						rsbusy[fxu1] =0;
					end
			//add		
				end else if(ibuff[1][15:12] == 1) begin
					if(fxu1!=12) begin
						rsrob[fxu1] = robTPt;
						rsbusy[fxu1] = 1;
						rsopcode[fxu1] = ibuff[1][15:12];
						if(!rbusy[ibuff[1][11:8]]) begin
							rsready0[fxu1] = 1;
							rsval0[fxu1] = regs[ibuff[1][11:8]];
						end else begin
							rsready0[fxu1] = 0;
							rssrc0[fxu1] = rsrc[ibuff[1][11:8]];
						end								
						if(!rbusy[ibuff[1][7:4]]) begin
							rsready1[fxu1] = 1;
							rsval1[fxu1] = regs[ibuff[1][7:4]];
						end else begin
							rsready1[fxu1] = 0;
							rssrc1[fxu1] = rsrc[ibuff[1][7:4]];
						end
						rsrc[ibuff[1][3:0]] = fxu1;
						rbusy[ibuff[1][3:0]] = 1; 
						valid1 = 1;

						robSrc[robTPt] = fxu1;
						robValid[robTPt] = 1;
						robOpcode[robTPt] = ibuff[1][15:12];
						robPc[robTPt] = iPc[1];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end
				end
end

			//next instr
				iFull = iFull-valid0-valid1;
				if(iFull != 2) begin
					state <= `F0;
				end
			
				if(valid0 && !valid1) begin
					iPc[0] <= iPc[1];
					ibuff[0] <= ibuff[1];
					iValid[0] <=1;
					iValid[1] <=0;
				end
				if (!valid0) begin
					rshalt <= 1;
				end

				fxu0 <=12;
				load0 <=12;
				fxu1 <=12;
				load1 <=12;
				valid0 <=0;
				valid1 <=0;
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
		//mov
			if(rsopcode[i] == 0) begin
					if(robSrc[rsrob[i]]==i  && robValid[rsrob[i]]) begin
						robData[rsrob[i]] = rsval0[i];
						robFinish[rsrob[i]] = 1;
					end
		//add
			end else if(rsopcode[i] == 1) begin
					if(robSrc[rsrob[i]]==i  && robValid[rsrob[i]]) begin
						robData[rsrob[i]] = rsval0[i]+rsval1[i];
						robFinish[rsrob[i]] = 1;
					end	
		//jeq helper
			end else if(rsopcode[i]==7) begin
					if(robSrc[rsrob[i]]==i  && robValid[rsrob[i]]) begin
						robData[rsrob[i]] = (rsval0[i]==rsval1[i])? 1: 0;
						robFinish[rsrob[i]] = 1;
					end
			end
		end
	end

	//jeq unit

		if(rsbusy[8] == 1 && rsready0[8] == 1 && rsready1[8] ==1) begin
		//jeq
			if(robSrc[rsrob[8]]==8  && robValid[rsrob[8]]) begin
				robData[rsrob[8]] = (rsval0[8]==1) ? rsval1[8]: 0;
				robFinish[rsrob[8]] = 1;
			end 
		end



	//load unit
		for(j=0; j<4; j=j+1) begin
			if(rsbusy[j] == 1 && rsready0[j] == 1) begin
				for (c = 0; c < 4; c = c + 1) begin
   	  				if(dinuse[c] == 1 && !dinCache) begin 
						if(daddress[c] == rsval0[j]) begin

							if(robSrc[rsrob[j]]==j  && robValid[rsrob[j]]) begin
								robData[rsrob[j]] = ddata[c];
								robFinish[rsrob[j]] = 1;
							end
							dinCache =1;
						end
					end
				end
				if(!dinCache&& loading == 0) begin
					res <= rsval0[j];
					ldin <= j;
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
					ddinCache = 1;
				end
			end
			if(ddinCache == 0) begin
			//FIFO
				if(dc < 3) begin
					dc <= dc +1;
				end else begin
					dc <= 0;
				end
				daddress[dc] <= res;
				ddata[dc] <= loadOut;		
			end
			ddinCache <= 0;
        end


// commit/ROB
		if(robFinish[robHPt] && robValid[robHPt]) begin
		//halt	
			if(robOpcode[robHPt] == 3) begin
				state <= `HALT;
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
				
				rsbusy[robSrc[robHPt]] <= 0;
				rsopcode[robSrc[robHPt]] <= 0;
				rsready0[robSrc[robHPt]] <= 0;
				rssrc0[robSrc[robHPt]] <= 16'hxxxx;
				rsval0[robSrc[robHPt]] <= 16'hxxxx;
				rsready1[robSrc[robHPt]] <= 0;
				rssrc1[robSrc[robHPt]] <= 16'hxxxx;
				rsval1[robSrc[robHPt]] <= 16'hxxxx;

				robValid[robHPt] = 0;
				robSrc[robHPt] = 0;
				robOpcode[robHPt]=0;
				robData[robHPt] = 0;
				robFinish[robHPt] = 0;
				robPc[robHPt] = 0;
			
		//jeq
			end else if(robOpcode[robHPt] == 6) begin
				if(robData[robHPt]!= 0) begin

					pc = robData[robHPt]+robPc[robHPt];
					state <= `F0;


					rshalt <=0;
					jeqhalt <=0;
					
					robHPt = 0;
					robTPt <= 0;
					
					iFull <=0;
					
					for (flush = 0; flush < 16; flush = flush +1) begin
						rsbusy[flush] <= 0;
						rsopcode[flush] <= 0;
						rsready0[flush] <= 0;
						rssrc0[flush] <= 16'hxxxx;
						rsval0[flush] <= 16'hxxxx;
						rsready1[flush] <= 0;
						rssrc1[flush] <= 16'hxxxx;
						rsval1[flush] <= 16'hxxxx;

						rbusy[flush] <=0;
	
						robValid[flush] <= 0;
						robOpcode[flush] <= 0;
						robSrc[flush] <= 0;
						robData[flush] <= 0;
						robFinish[flush] = 0;
						robPc[flush] <= 0;
					end
					
				end else begin

					rsbusy[robSrc[robHPt]] = 0;
					rsopcode[robSrc[robHPt]] = 0;
					rsready0[robSrc[robHPt]] = 0;
					rssrc0[robSrc[robHPt]] = 16'hxxxx;
					rsval0[robSrc[robHPt]] = 16'hxxxx;
					rsready1[robSrc[robHPt]] = 0;
					rssrc1[robSrc[robHPt]] = 16'hxxxx;
					rsval1[robSrc[robHPt]] = 16'hxxxx;

					robValid[robHPt] = 0;
					robSrc[robHPt] = 0;
					robOpcode[robHPt]=0;
					robData[robHPt] = 0;
					robFinish[robHPt] = 0;
					robPc[robHPt] = 0;
					
					rshalt <= 0;

					if(robHPt != 15) begin
						robHPt = robHPt +1;
					end else begin
						robHPt = 0;
					end
				end
		
			end else begin
				for(e=0; e<12; e=e+1) begin
					if(e != robSrc[robHPt]) begin
						if(rssrc0[e] == robSrc[robHPt] && rsready0[e]==0) begin
							rsval0[e] = robData[robHPt];
							rsready0[e] = 1;
						end
						if(rssrc1[e] == robSrc[robHPt]  && rsready1[e]==0) begin
							rsready1[e] = 1;
							rsval1[e] = robData[robHPt];
						end
					end
				end
				for(f=0; f<16; f=f+1) begin
					if(rsrc[f] == robSrc[robHPt] && rbusy[f]==1) begin
						rbusy[f] = 0;
						rsrc[f] = 0;
						regs[f] = robData[robHPt];
					end
				end

				rsbusy[robSrc[robHPt]] <= 0;
				rsopcode[robSrc[robHPt]] <= 0;
				rsready0[robSrc[robHPt]] <= 0;
				rssrc0[robSrc[robHPt]] <= 16'hxxxx;
				rsval0[robSrc[robHPt]] <= 16'hxxxx;
				rsready1[robSrc[robHPt]] <= 0;
				rssrc1[robSrc[robHPt]] <= 16'hxxxx;
				rsval1[robSrc[robHPt]] <= 16'hxxxx;

				robValid[robHPt] = 0;
				robSrc[robHPt] = 0;
				robOpcode[robHPt]=0;
				robData[robHPt] = 0;
				robFinish[robHPt] = 0;
				robPc[robHPt] = 0;
				
				rshalt <= 0;

				if(robHPt != 15) begin
					robHPt = robHPt +1;
				end else begin
					robHPt = 0;
				end

			end
		end
    end

endmodule

