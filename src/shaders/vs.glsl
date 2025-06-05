struct VertexInput
{
  float2 pos : POSITION;
  float3 color : COLOR0;
};

struct VertexOutput
{
  float4 pos : SV_POSITION;
  float3 color : COLOR0;
};

VertexOutput VS(VertexInput input)
{
  VertexOutput output;
  output.pos = float4(input.pos, 0.0, 1.0);
  output.color = input.colot;
  return output;
}
