struct VertexInput
{
  float2 pos : POSITION;
  uint col : COLOR0;
};

struct VertexOutput
{
  float4 pos : SV_POSITION;
  float4 col : COLOR0;
};

VertexOutput VS(VertexInput input)
{
  VertexOutput output;
  output.pos = float4(input.pos, 0.0, 1.0);
  output.col = unpackUnorm4x8(input.col);
  return output;
}
