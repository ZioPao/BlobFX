#include "ReShade.fxh"

uniform int iterations <
    ui_type = "drag";
    ui_min = 0; ui_max = 500;
    ui_label = "Iterations";
    ui_tooltip = "Accuracy of the effect";
> = 2.00;
uniform float strength <
    ui_type = "drag";
    ui_min = 0.00; ui_max = 0.95;
    ui_label = "Strength";
    ui_tooltip = "Strength of the effect";
> = 0.3;
//Samplers


texture2D colorTex { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT; Format = RGBA8;};

texture BlurTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler BlurSampler { Texture = BlurTex;};



//////////////////////////////////////////////////////
/* Pixel Shaders*/
//////////////////////////////////////////////////////

void MotionBlurPS(in float2 texcoord : TEXCOORD, out float4 color : SV_TARGET0){

    //Got from GaussianBlur by Ioxa
    float offset[15] = { 0.0, 1.4953705027, 3.4891992113, 5.4830312105, 7.4768683759, 9.4707125766, 11.4645656736, 13.4584295168, 15.4523059431, 17.4461967743, 19.4401038149, 21.43402885, 23.4279736431, 25.4219399344, 27.4159294386 };
    float weight[15] = { 0.0443266667, 0.0872994708, 0.0820892038, 0.0734818355, 0.0626171681, 0.0507956191, 0.0392263968, 0.0288369812, 0.0201808877, 0.0134446557, 0.0085266392, 0.0051478359, 0.0029586248, 0.0016187257, 0.0008430913 };

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