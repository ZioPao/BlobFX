/* 
Interlaced effect PS v1.0.4 (c) 2018 Jacob Maximilian Fober, 
(blending fix thanks to Marty McFly)

Modified by Pao

This work is licensed under the Creative Commons 
Attribution-ShareAlike 4.0 International License. 
To view a copy of this license, visit 
http://creativecommons.org/licenses/by-sa/4.0/.
*/
#include "ReShade.fxh"

#ifndef INTERLACED_RES_DIVIDE
 #define INTERLACED_RES_DIVIDE       1
#endif




uniform float scanlineScaling <
	ui_type = "drag";
	ui_category = "Camera";    
	ui_label = "Scanline Size";
	ui_min = 1.0f; ui_max = 20.0f;
	ui_step = 2f;

> = 2f;

uniform int frameRetentionDuration <
	ui_type = "drag";
	ui_category = "Camera";
	ui_label = "Frame Retention";			
	ui_min = 0; ui_max = 4;
	ui_step = 1;

> = 1;		//Only power of 2

uniform bool stillShot <
  	ui_category = "Screenshots";    
	ui_label = "Still Shot Mode";
> = false;



uniform int frameCount < source = "framecount";>;


// Previous frame render target buffer
texture InterlacedTargetBuffer { Width = BUFFER_WIDTH/INTERLACED_RES_DIVIDE; Height = BUFFER_HEIGHT/INTERLACED_RES_DIVIDE; };

sampler InterlacedBufferSampler { Texture = InterlacedTargetBuffer;
	MagFilter = POINT;
	MinFilter = POINT;
	MipFilter = POINT;
};

void InterlacedTargetPass(float4 vpos : SV_Position, float2 uv : TEXCOORD,
out float4 target : SV_Target)
{

	// Interlaced rows boolean
	bool OddFrame = stillShot ? frac(frameCount) != 0 : frac(frameCount * (1.5f/pow(2,frameRetentionDuration))) != 0;
	bool bottomHalf = uv.y > 0.5f;

	// Flip flop saving texture between top and bottom half of the RenderTarget
	float2 renderCoordinates;
	renderCoordinates.x = uv.x;
	renderCoordinates.y = uv.y * 2;

	// Adjust flip flop coordinates
	float hPixelSizeY = ReShade::PixelSize.y * 0.5f;			
	renderCoordinates.y -= bottomHalf ? 1 + hPixelSizeY : hPixelSizeY;

	// Flip flop save to Render Target texture
	target = (OddFrame ? bottomHalf : uv.y < 0.5) ? float4(tex2D(ReShade::BackBuffer, renderCoordinates).rgb, 1) : 0;
	// Outputs raw BackBuffer to InterlacedTargetBuffer for the next frame
}

void InterlacedPS(float4 vpos : SV_Position, float2 uv : TEXCOORD,
out float3 target : SV_Target)
{
	
	//scanline management
	float scanlineSize = 1/scanlineScaling;
	bool oddRow = frac(int(ReShade::ScreenSize.y * uv.y ) * scanlineSize) != 0;


	bool oddFrame = stillShot ? frac(frameCount) != 0 : 
					frac(frameCount * (1.5f/pow(2,frameRetentionDuration))) != 0;


	// Calculate coordinates of BackBuffer texture saved at previous frame
	float2 renderCoordinates = float2(uv.x, uv.y * 0.5f);
	float qPixelSizeY = ReShade::PixelSize.y * 0.25;
	renderCoordinates.y += oddFrame ? qPixelSizeY : qPixelSizeY + 0.5f;

	// Sample odd and even rows
	target = oddRow ? tex2D(ReShade::BackBuffer, uv).rgb : 
						tex2D(InterlacedBufferSampler, renderCoordinates).rgb;

	// Preview RenderTarget
	//Image = tex2D(InterlacedBufferSampler, UvCoord).rgb;
}

technique Interlaced
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = InterlacedTargetPass;
		RenderTarget = InterlacedTargetBuffer;
		ClearRenderTargets = false;
		BlendEnable = true;
		BlendOp = ADD; 	//mimic lerp
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;		//Destination color. Pixel that already exists
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = InterlacedPS;
	}
}