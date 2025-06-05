Texture2D texture0;
SamplerState sampler0;

struct VertexOutput
{
  float4 position : SV_POSITION;
  float2 uv : TEXCOORD0;
};

float4 PS(VertexOutput input) : SV_Target
{
  float4 color = texture0.Sample(sampler0, input.uv);
  color.a = color.r * color.g * color.b;
  return color;
}
