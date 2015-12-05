`timescale 1ps/1ps

//
// States:
//

// Fetch
`define F0 0
`define F1 1

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

	reg [5:0]state = `F0;

reg temp = 0;

	//pc for fetching
	reg[15:0]fPc = 0;
	wire [4:0]set = fPc[4:0];
	wire [10:0]offset = fPc[15:5];

	//icache-direct mapping; mapping through last [4:0] instead of [15:11] since most instructions are linear
	reg[15:0]idata[0:31];
	reg[10:0]iaddress[0:31];
	reg iinuse[0:31];
	reg iinCache = 0;

	//dcache-fully associative
	reg[9:0]daddress[0:3];
	reg[3:0]dinuse[0:3];
	reg[15:0]ddata[0:3];
	reg dinCache = 0;
	reg ifLoad = 0;
	reg loading = 0;
	reg [15:0]ldadd = 0;
	reg [3:0]dc = 0;

	//instruction buffer
	reg [3:0]instrFull = 0;
	reg instrValid[0:1];
	reg [15:0]instrPc[0:1];
	reg [15:0]instrData[0:1];

	wire instrDep = (instrData[1][11:8] != instrData[0][3:0] && instrData[1][7:4] != instrData[0][3:0]);
	wire instrFxu0 = (instrData[0][15:12] == 0 || instrData[0][15:12] == 1 || instrData[0][15:12] == 5 || instrData[0][15:12] == 6);
	wire instrFxu1 = (instrData[1][15:12] == 0 || instrData[1][15:12] == 1|| instrData[1][15:12] == 5 || instrData[1][15:12] == 6);
	wire instrLd0 = (instrData[0][15:12] == 4 || instrData[0][15:12] == 5);
	wire instrLd1 = (instrData[1][15:12] == 4 || instrData[1][15:12] == 5);

	reg valid0 = 0;
	reg valid1 = 0;

	reg [3:0]load0 =10;
	reg[3:0]load1 =10;
	reg[3:0]fxu0 =10;
	reg[3:0]fxu1 =10;
	reg[3:0]other0 =10;
	reg[3:0]other1 = 10;


	//stalling
	reg hStall =0;
	reg rsStall = 0;
  	wire iStall = rsStall || hStall;

    // regs
    reg [15:0]regs[0:15];
	reg rbusy[0:15];
	reg [7:0]rsrc[0:15];

	//rs ; 0-3 are ld, 4-7 are fxu, 8 is jeq, 9 is halt
	reg rsbusy[0:9];
	reg [3:0]rsopcode[0:9];
	reg rsready0[0:9];
	reg [7:0]rssrc0[0:9];
	reg [15:0]rsval0[0:9];
	reg rsready1[0:9];
	reg [7:0]rssrc1[0:9];
	reg [15:0]rsval1[0:9];

	//reorder buffer
	reg [15:0]robData[0:15];
	reg [15:0]robSrc[0:15];
	reg robFinish[0:15];
	reg [15:0]robPc[0:15];
	reg [3:0]robHPt = 0;
	reg [3:0]robTPt = 0;

	reg inJmp = 0;
	
//for loop counters
reg[3:0]a = 0;
reg[3:0]b = 0;
reg[3:0]c = 0;
reg[3:0]d = 0;
reg[3:0]e = 0;
reg[3:0]f = 0; 			
reg[3:0]g = 0;	
reg[3:0]i = 0;
reg[3:0]j = 0;
reg[3:0]x = 0;
reg[3:0]y = 0;
reg[3:0]z = 0;
reg[3:0]cv = 0;
reg [3:0]w = 0;
reg [3:0]flush = 0;
reg [3:0]v = 0;
reg [3:0]vv = 0;

	//initialization for caches, regs, rs
	initial begin
		for(v=0; v<4; v=v+1)begin
			dinuse[v] = 0;
			iinuse[v] = 0;
		end
		for(i=0; i<10; i = i+1) begin
				rsbusy[i] = 0;
				rsopcode[i] = 0;
				rsready0[i] = 0;
				rssrc0[i] = 0;
				rsval0[i] = 16'hxxxx;
				rsready1[i] = 0;
				rssrc1[i] = 0;
				rsval1[i] = 16'hxxxx;
		end
	end
	
    // fetch 
    wire [15:0]fetchOut;
    wire fetchReady;

    // load 
    wire [15:0]loadOut;
    wire loadReady;
    reg [15:0]res; // what to write in the register file

    mem i0(clk,
       /* fetch port */
       (state == `F0),
       fPc,
       fetchReady,
       fetchOut,

       /* load port */
       ifLoad,
       res,
       loadReady,
       loadOut

);

reg fetch = 0;

    always @(posedge clk) begin
		ifLoad <= 0;
        case(state)
        `F0: begin
			fetch  <= 1;
            state <= `F1;
        end
        `F1: begin
            if (fetchReady) begin
				fetch = 0;
               	idata[set] = fetchOut;
				iaddress[set] = offset;
				iinuse[set] = 1; 
            end

			if(instrFull != 2) begin
				if(iinuse[set] == 1 && iaddress[set]==offset) begin
			//checking jmp 
					if(idata[set][15:12]==2) begin
						fPc <= idata[set][11:0];
						inJmp =1;
					end 
					if (!inJmp) begin
						instrValid[instrFull] = 1;
						instrPc[instrFull] = fPc;
						instrData[instrFull] = idata[set];
						instrFull <= instrFull + 1;
						if(instrFull == 1) begin
							state <=`S0;
						end
						fPc <= fPc+1;
					end
				end else begin
					state <= `F0;
				end
				inJmp <= 0;
			end else begin
				state <= `S0;
			end
        end

        `S0: begin
			if(!iStall) begin
			//gettin rs for 1st instr
				if(instrFxu0) begin
					for(a=4; a<8; a=a+1) begin
						if(rsbusy[a] !=1 && fxu0==10) begin
							fxu0 = a;
							rsbusy[a] =1;
						end
					end	
				end
				if(instrLd0) begin
					for(b=0; b<4; b=b+1) begin
						if(!rsbusy[b] && load0==10) begin
							load0 = b;
							rsbusy[b] =1;
						end
					end
				end
				if(instrData[0][15:12] == 3) begin
					if(!rsbusy[9]) begin
						other0 = 9;
						rsbusy[9] =1;
					end
				end else if(instrData[0][15:12] == 6) begin
					if(fxu0 !=10 && !rsbusy[8]) begin
						other0 = 8;
						rsbusy[8] = 1;
					end
				end
	
 			//getting rs for 2nd instr
				if(instrDep && instrData[0][15:12] != 3) begin
					if(instrFxu1) begin
						for(c=4; c<8; c=c+1) begin
							if(!rsbusy[c] && fxu1==10) begin
								fxu1 = c;
								rsbusy[c] =1;
							end
						end	
					end
					if(instrLd1) begin
						for(d=0; d<4; d=d+1) begin
							if(!rsbusy[d] && load1==10) begin
								load1 = d;
								rsbusy[d] =1;
							end
						end
					end
					if(instrData[1][15:12] == 3) begin
						if(!rsbusy[9]) begin
							other1 = 9;
							rsbusy[9] =1;
						end		
					end else if(instrData[1][15:12] == 6) begin
						if(fxu0 !=10 && !rsbusy[8]) begin
							other1 = 8;
							rsbusy[8] = 1;
						end
					end
				end


			//mov	
				if(instrData[0][15:12] == 0) begin
					if(fxu0 != 10) begin

						rsbusy[fxu0] = 1;
						rsopcode[fxu0] = instrData[0][15:12];
						rsready0[fxu0] = 1;
						rsval0[fxu0] = instrData[0][11:4];
						rsready1[fxu0] = 1;
						rsval1[fxu0] = instrData[0][3:0];
						rbusy[instrData[0][3:0]] = 1;
						rsrc[instrData[0][3:0]] = fxu0;
						
						valid0 = 1;
						instrFull =  instrFull-1;

						robSrc[robTPt] = fxu0;
						robPc[robTPt] = instrPc[0];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end
			//add		
				end else if(instrData[0][15:12] == 1) begin
					if(fxu0 != 10) begin
						rsbusy[fxu0] = 1;
						rsopcode[fxu0] = instrData[0][15:12];
						if(!rbusy[instrData[0][11:8]]) begin
							rsready0[fxu0] = 1;
							rsval0[fxu0] = regs[instrData[0][11:8]];
						end else begin
							rsready0[fxu0] = 0;
							rssrc0[fxu0] = rsrc[instrData[0][11:8]];
						end								
						if(!rbusy[instrData[0][7:4]]) begin
								rsready1[fxu0]=1;
							rsval1[fxu0] = regs[instrData[0][7:4]];
						end else begin
								rsready1[fxu0] = 0;
							rssrc1[fxu0] = rsrc[instrData[0][7:4]];
						end
						rsrc[instrData[0][3:0]] = fxu0;
						rbusy[instrData[0][3:0]] = 1; 

						valid0 = 1;
						instrFull =  instrFull-1;

						robSrc[robTPt] = fxu0;
						robPc[robTPt] = instrData[0][15:12];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end	
				
			//halt
				end else if(instrData[0][15:12] == 3) begin
					if(other0 != 10) begin
						rsbusy[9] = 1;
						rsopcode[9] = 3;
						rsready0[9] =1;
						rsready1[9] =1;

						hStall <=1;

						valid0 = 1;
						instrFull =  instrFull-1;

						robSrc[robTPt] = other0;
						robPc[robTPt] = instrData[0][15:12];
						robFinish[robTPt] = 1;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end
			//load
				end else if(instrData[0][15:12] == 4) begin
					if(load0 !=10)  begin
						rsbusy[load0] = 1;
						rsopcode[load0] = instrData[0][15:12];
						rsready0[load0] = 1;
						rsval0[load0] = instrData[0][11:4];
						rsready1[load0] = 1;
						rsval1[load0] = instrData[0][3:0];
						rbusy[instrData[0][3:0]] = 1;
						rsrc[instrData[0][3:0]] = load0;

						valid0 = 1;
						instrFull =  instrFull-1;

						robSrc[robTPt] = load0;
						robPc[robTPt] = instrData[0][15:12];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end
			//ldr	
				end else if(instrData[0][15:12] == 5) begin
					if(load0 !=10 && fxu0 != 10)  begin
						rsbusy[fxu0] = 1;
						rsopcode[fxu0] = 1;
						if(!rbusy[instrData[0][11:8]]) begin
							rsready0[fxu0] = 1;
							rsval0[fxu0] = regs[instrData[0][11:8]];
						end else begin
							rsready0[fxu0] = 0;
							rssrc0[fxu0] = rsrc[instrData[0][11:8]];
						end								
						if(!rbusy[instrData[0][7:4]]) begin
							rsready1[fxu0] = 1;
							rsval1[fxu0] = regs[instrData[0][7:4]];
						end else begin
							rsready1[fxu0] = 0;
							rssrc1[fxu0] = rsrc[instrData[0][7:4]];
						end

						rsbusy[load0] = 1;
						rsopcode[load0] = 4;
						rsready0[load0] = 0;
						rssrc0[load0] = fxu0;
						rsready1[load0] = 1;
						rsval1[load0] = instrData[0][3:0];
						rbusy[instrData[0][3:0]] = 1;
						rsrc[instrData[0][3:0]] = load0;

						valid0 = 1;
						instrFull =  instrFull-1;

						robSrc[robTPt] = load0;
						robPc[robTPt] = instrData[0][15:12];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end

			//jeq
				end else if(instrData[0][15:12] == 6) begin
					if(other0 !=10 && fxu0 !=10)  begin
						rsbusy[fxu0] = 1;
						rsopcode[fxu0] = 7;
						if(!rbusy[instrData[0][11:8]]) begin
							rsready0[fxu0] = 1;
							rsval0[fxu0] = regs[instrData[0][11:8]];
						end else begin
							rsready0[fxu0] = 0;
							rssrc0[fxu0] = rsrc[instrData[0][11:8]];
							end								
							if(!rbusy[instrData[0][7:4]]) begin
								rsready1[fxu0] = 1;
								rsval1[fxu0] = regs[instrData[0][7:4]];
						end else begin
							rsready1[fxu0] = 0;
							rssrc1[fxu0] = rsrc[instrData[0][7:4]];
						end

						rsopcode[other0] = 2;
						rsready0[other0] = 0;
						rssrc0[other0] = fxu0;
						rsready1[other0] =1;
						rsval1[other0] = instrData[0][3:0];

						valid0 = 1;
						instrFull =  instrFull-1;

						robSrc[robTPt] = other0;
						robPc[robTPt] = instrData[0][15:12];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	

					end
				end

//dispatching 2nd instr; copy of 1st instr
			//mov	
				if(instrData[1][15:12] == 0) begin
					if(fxu1 != 10) begin
						rsbusy[fxu1] = 1;
						rsopcode[fxu1] = instrData[1][15:12];
						rsready0[fxu1] = 1;
						rsval0[fxu1] = instrData[1][11:4];
						rsready1[fxu1] = 1;
						rsval1[fxu1] = instrData[1][3:0];
						rbusy[instrData[1][3:0]] = 1;
						rsrc[instrData[1][3:0]] = fxu1;
						
						valid1 = 1;
						instrFull =  instrFull-1;

						robSrc[robTPt] = fxu1;
						robPc[robTPt] = instrData[1][15:12];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end
			//add		
				end else if(instrData[1][15:12] == 1) begin
					if(fxu1 != 10) begin
						rsbusy[fxu1] = 1;
						rsopcode[fxu1] = instrData[1][15:12];
						if(!rbusy[instrData[1][11:8]]) begin
							rsready0[fxu1] = 1;
							rsval0[fxu1] = regs[instrData[1][11:8]];
						end else begin
							rsready0[fxu1] = 1;
							rssrc0[fxu1] = rsrc[instrData[1][11:8]];
						end								
						if(!rbusy[instrData[1][7:4]]) begin
								rsready1[fxu1]=1;
							rsval1[fxu1] = regs[instrData[1][7:4]];
						end else begin
								rsready1[fxu1] = 0;
							rssrc1[fxu1] = rsrc[instrData[1][7:4]];
						end
						rsrc[instrData[1][3:0]] = fxu1;
						rbusy[instrData[1][3:0]] = 1; 

						valid1 = 1;
						instrFull =  instrFull-1;

						robSrc[robTPt] = fxu1;
						robPc[robTPt] = instrData[1][15:12];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end	
			//halt
				end else if(instrData[0][15:12] == 3) begin
					if(other1 != 10) begin
						rsbusy[9] = 1;
						rsopcode[9] = 3;
						rsready0[9] =1;
						rsready1[9] =1;
							
						hStall <= 1;

						valid1 = 1;
						instrFull =  instrFull-1;

						robSrc[robTPt] = other1;
						robPc[robTPt] = instrData[1][15:12];
						robFinish[robTPt] = 1;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end
			//load
				end else if(instrData[1][15:12] == 4) begin
					if(load1 !=10)  begin
						rsbusy[load1] = 1;
						rsopcode[load1] = instrData[1][15:12];
						rsready0[load1] = 1;
						rsval0[load1] = instrData[1][11:4];
						rsready1[load1] = 1;
						rsval1[load1] = instrData[1][3:0];
						rbusy[instrData[1][3:0]] = 1;
						rsrc[instrData[1][3:0]] = load0;

						valid1 = 1;
						instrFull =  instrFull-1;

						robSrc[robTPt] = load1;
						robPc[robTPt] = instrData[1][15:12];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end
			//ldr	
				end else if(instrData[1][15:12] == 5) begin
					if(load1 !=10 && fxu1 != 10)  begin
						rsbusy[fxu1] = 1;
						rsopcode[fxu1] = 1;
						if(!rbusy[instrData[1][11:8]]) begin
							rsready0[fxu1] = 1;
							rsval0[fxu1] = regs[instrData[1][11:8]];
						end else begin
							rsready0[fxu1] = 0;
							rssrc0[fxu1] = rsrc[instrData[1][11:8]];
						end								
						if(!rbusy[instrData[1][7:4]]) begin
							rsready1[fxu1] = 1;
							rsval1[fxu1] = regs[instrData[1][7:4]];
						end else begin
							rsready1[fxu1] = 0;
							rssrc1[fxu1] = rsrc[instrData[1][7:4]];
						end

						rsbusy[load1] = 1;
						rsopcode[load1] = 4;
						rsready0[load1] = 0;
						rssrc0[load1] = fxu1;
						rsready1[load1] = 1;
						rsval1[load1] = instrData[1][3:0];
						rbusy[instrData[1][3:0]] = 1;
						rsrc[instrData[1][3:0]] = load1;

						valid0 = 1;
						instrFull =  instrFull-1;

						robSrc[robTPt] = load1;
						robPc[robTPt] = instrData[1][15:12];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	
					end

			//jeq
				end else if(instrData[1][15:12] == 6) begin
					if(other1 !=10 && fxu1 !=10)  begin
						rsbusy[fxu1] = 1;
						rsopcode[fxu1] = 7;
						if(!rbusy[instrData[1][11:8]]) begin
							rsready0[fxu1] = 1;
							rsval0[fxu1] = regs[instrData[1][11:8]];
						end else begin
							rsready0[fxu1] = 0;
							rssrc0[fxu1] = rsrc[instrData[1][11:8]];
							end								
							if(!rbusy[instrData[1][7:4]]) begin
								rsready1[fxu1] = 1;
								rsval1[fxu1] = regs[instrData[1][7:4]];
						end else begin
							rsready1[fxu1] = 0;
							rssrc1[fxu1] = rsrc[instrData[1][7:4]];
						end

						rsopcode[other1] = 2;
						rsready0[other1] = 0;
						rssrc0[other1] = fxu1;
						rsready1[other1] =1;
						rsval1[other1] = instrData[1][3:0];

						valid1 = 1;
						instrFull =  instrFull-1;

						robSrc[robTPt] = other1;
						robPc[robTPt] = instrData[1][15:12];
						robFinish[robTPt] = 0;	
						if(robTPt!=15) begin
							robTPt = robTPt+1;
						end else begin
							robTPt = 0;
						end	

					end
				end

				if(instrFull != 2) begin
					state <= `F1;
				end
			
				if(valid0 && !valid1) begin
					instrPc[0] <= instrPc[1];
					instrData[0] <= instrData[1];
				end
				if (!valid0) begin
					rsStall <= 1;
				end
				if(!valid1) begin
					rsbusy[fxu1] <= 0;
					rsbusy[load1] <= 0;
					rsbusy[other1] <= 0;
				end

				valid0 <= 0;
				valid1 <= 0;

				load0 <= 10;
				load1 <= 10;
				fxu0 <= 10;
				fxu1 <= 10;
				other0 <= 10;
				other1 <= 10;
			end
		end
        `HALT: begin

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
					for(x = 0; x<16; x=x+1) begin
						if(robSrc[x] == i) begin
							robData[x] = rsval0[i];
							robFinish[x] = 1;
							temp<=1;
						end
					end
			//add
				end else if(rsopcode[i] == 1) begin
					for(x = 0; x<16; x=x+1) begin
						if(robSrc[x] == i) begin
							robData[x] = rsval0[i]+rsval1[i];
							robFinish[x] = 1;
						end
					end
				end else if(rsopcode[i] == 7) begin
					robData[9] = (rsval0[i] == rsval1[i]);
					robFinish[9] = 1;

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
				for (cv = 0; cv < 4; cv = cv + 1) begin
   	  				if(dinuse[c] == 1 && !dinCache) begin 
						if(daddress[cv] == rsval0[j]) begin
							for(y = 0; y<16; y=y+1) begin
								if(robSrc[y] == i) begin
									robData[y] = ddata[cv];
									robFinish[y] = 1;
								end
							end
							dinCache = 1;
						end
					end
				end
				if(dinCache == 0 && loading == 0) begin
					res <= rsval0[j];
					ldadd <= j;
					ifLoad <= 1;
					loading <= 1;
				end
				dinCache = 0;
			end
		end
        if (loadReady) begin 
			loading <= 0;
			for(z = 0; z<16; z=z+1) begin
						if(robSrc[z] == ldadd) begin
							robData[z] = rsval0[ldadd];
							robFinish[z] = 1;
						end
					end
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


	// commit/ROB
		if(robFinish[robHPt]==1) begin
		//halt	

			if(robPc[robHPt] == 3) begin
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

				//should probably also flush?
			
		//jeq
			end else if(robPc[robHPt] == 6) begin
				if(robData[robHPt]) begin
					state <= `F1;
					fPc <= robPc[robHPt] + rsval1[robSrc[robHPt]];

					rsStall <=0;
					hStall <=0;
					
					robHPt <= 0;
					robTPt <=  0;
					
					for (flush = 0; flush < 16; flush = flush +1) begin
						rsbusy[flush] <= 0;
						rsopcode[flush] <= 0;
						rsready0[flush] <= 0;
						rssrc0[flush] <= 16'hxxxx;
						rsval0[flush] <= 16'hxxxx;
						rsready1[flush] <= 0;
						rssrc1[flush] <= 16'hxxxx;
						rsval1[flush] <= 16'hxxxx;
	
						robSrc[flush] = 0;
						robData[flush] = 0;
						robFinish[flush] = 0;
						robPc[flush] = 0;
					end
					
				end
				//do  nothing if not equal
				//flush otherwise
				//clear out rs, rob, ib, stalls
				//change fPc to new value; robHPt = 0; robTPt = 0;
		
			end else begin
				for(e=0; e<10; e=e+1) begin
					if(e != robSrc[robHPt]) begin
						if(rssrc0[e] == robSrc[robHPt] && rsready0[e]==0) begin
							rsval0[e] <= robData[robHPt];
							rsready0[e] <= 1;
						end
						if(rssrc1[e] == robSrc[robHPt]  && rsready1[e]==0) begin
							rsready1[e] <= 1;
							rsval1[e] <= robData[robHPt];
						end
					end
				end
				for(f=0; f<16; f=f+1) begin
					if(rsrc[f] == robSrc[robHPt] && rbusy[f]==1) begin
						rbusy[f] <= 0;
						rsrc[f] <= 0;
						regs[f] <= robData[robHPt];
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

				robSrc[robHPt] = 0;
				robData[robHPt] = 0;
				robFinish[robHPt] = 0;
				robPc[robHPt] = 0;
				
				rsStall <= 0;

				if(robHPt != 15) begin
					robHPt = robHPt +1;
				end else begin
					robHPt = 0;
				end

			end
		end

    end

endmodule

