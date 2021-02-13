#include "ReShade.fxh"

uniform int iterations <
    ui_type = "drag";
    ui_min = 1; ui_max = 100;
    ui_label = "Iterations";
    ui_tooltip = "Accuracy of the effect";
> = 2.00;
uniform float strength <
    ui_type = "drag";
    ui_min = 0.00; ui_max = 0.8;
    ui_label = "Strength";
    ui_tooltip = "Strength of the effect. Higher values will cause ghosting";
> = 0.4;
//Samplers


texture2D colorTex { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT; Format = RGBA8;};

texture BlurTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler BlurSampler { Texture = BlurTex;};



//////////////////////////////////////////////////////
/* Pixel Shaders*/
//////////////////////////////////////////////////////

void MotionBlurPS(in float2 texcoord : TEXCOORD, out float4 color : SV_TARGET0){

    for (int i = 0; i < iterations; i++){
 
        color = tex2D(BlurSampler, texcoord);
        color = lerp(tex2D(ReShade::BackBuffer, texcoord), color, strength);
    }

}



void Second_Pass_PS(in float2 texcoord : TEXCOORD, out float4 color : SV_TARGET0){

    color = tex2D(BlurSampler, texcoord);
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


technique BadMotionBlur {

    pass{
        VertexShader = PostProcessVS;
        PixelShader = MotionBlurPS;
        RenderTarget0 = BlurTex;
    }

     pass{
         VertexShader = PostProcessVS;
         PixelShader = Second_Pass_PS;
     }
}