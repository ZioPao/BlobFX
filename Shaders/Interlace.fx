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





uniform float scanlineSize <
	ui_type = "drag";
	ui_category = "Camera";    
	ui_label = "Scanline Size";
	ui_min = 0.0f; ui_max = 20.0f;
	ui_step = 2f;

> = 2f;

uniform float retentionOldFrame <
	ui_type = "drag";
	ui_category = "Camera";
	ui_label = "Old Frame Retention";
	ui_min = 0.0f; ui_max = 10.0f;
	ui_step = 0.05f;

> = 0.5f;

uniform bool stillShot <
  	ui_category = "Screenshots";    
	ui_label = "Still Shot Mode";
> = false;



#ifndef ShaderAnalyzer
	uniform int FrameCount < source = "framecount"; >;
#endif

// Previous frame render target buffer
texture InterlacedTargetBuffer { Width = BUFFER_WIDTH/INTERLACED_RES_DIVIDE; Height = BUFFER_HEIGHT/INTERLACED_RES_DIVIDE; };

sampler InterlacedBufferSampler { Texture = InterlacedTargetBuffer;
	MagFilter = POINT;
	MinFilter = POINT;
	MipFilter = POINT;
};

void InterlacedTargetPass(float4 vpos : SV_Position, float2 UvCoord : TEXCOORD,
out float4 Target : SV_Target)
{

	// Interlaced rows boolean
	bool OddPixel = frac(int(ReShade::ScreenSize.y * UvCoord.y) * (1/scanlineSize)) != 0;  
	bool OddFrame = stillShot ? frac(FrameCount) != 0 : frac(FrameCount * 1.5f / retentionOldFrame) != 0;
 
	bool BottomHalf = UvCoord.y > 0.5f;


	// Flip flop saving texture between top and bottom half of the RenderTarget
	float2 Coordinates;
	Coordinates.x = UvCoord.x;
	Coordinates.y = UvCoord.y * 2;
	// Adjust flip flop coordinates
	float hPixelSizeY = ReShade::PixelSize.y * 0.5f;
	Coordinates.y -= BottomHalf ? 1 + hPixelSizeY : hPixelSizeY;
	// Flip flop save to Render Target texture
	Target = (OddFrame ? BottomHalf : UvCoord.y < 0.5) ?
		float4(tex2D(ReShade::BackBuffer, Coordinates).rgb, 1) : 0;
	// Outputs raw BackBuffer to InterlacedTargetBuffer for the next frame
}

void InterlacedPS(float4 vpos : SV_Position, float2 UvCoord : TEXCOORD,
out float3 Image : SV_Target)
{
	// Interlaced rows boolean
	bool OddPixel = frac(int(ReShade::ScreenSize.y * UvCoord.y) * (1/scanlineSize)) != 0;
	bool OddFrame = stillShot ? frac(FrameCount) != 0 : frac(FrameCount * 1.5f / retentionOldFrame) != 0;

	// Calculate coordinates of BackBuffer texture saved at previous frame
	float2 Coordinates = float2(UvCoord.x, UvCoord.y * 0.5f);
	float qPixelSizeY = ReShade::PixelSize.y * 0.25;
	Coordinates.y += OddFrame ? qPixelSizeY : qPixelSizeY + 0.5f;
	// Sample odd and even rows
	Image = OddPixel ? tex2D(ReShade::BackBuffer, UvCoord).rgb: tex2D(InterlacedBufferSampler, Coordinates).rgb;

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