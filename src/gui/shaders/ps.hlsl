struct VertexOutput
{
  float4 pos : SV_POSITION;
  float2 uv  : TEXCOORD0;
  float4 col : COLOR0;
  uint flags : TEXCOORD1;
};

sampler sampler0;
Texture2D texture0;

float4 PS(VertexOutput input) : SV_Target
{
  return input.col * texture0.Sample(sampler0, input.uv);
}
