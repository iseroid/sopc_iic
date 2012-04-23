module de0nano_iic(
	input          CLOCK_50,
	input  [  1:0] KEY,
	output         G_SENSOR_CS_N,
	inout          I2C_SCLK,
	inout          I2C_SDAT
);
	wire         clk;
	wire         rst_n;

	wire         scl_in_w;
	wire         scl_out_w;
	wire         sda_in_w;
	wire         sda_out_w;

	assign clk = CLOCK_50;
	assign rst_n = KEY[0];

	assign G_SENSOR_CS_N = 1'b1;

	// I2C Tri-state buffer
	assign scl_in_w = I2C_SCLK;
	assign I2C_SCLK = scl_out_w ? 1'bz : 1'b0;
	assign sda_in_w = I2C_SDAT;
	assign I2C_SDAT = sda_out_w ? 1'bz : 1'b0;

	de0nano_iic_sopc de0nano_iic_sopc(
		.clk_0                       ( clk ),
		.reset_n                     ( rst_n ),
		.scl_in_to_the_iic_0         ( scl_in_w ),
		.scl_out_from_the_iic_0      ( scl_out_w ),
		.sda_in_to_the_iic_0         ( sda_in_w ),
		.sda_out_from_the_iic_0      ( sda_out_w )
	);

endmodule

