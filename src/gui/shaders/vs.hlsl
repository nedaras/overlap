struct VertexInput
{
  float2 pos : POSITION;
  float2 uv  : TEXCOORD0;
  uint col   : COLOR0;
};

struct VertexOutput
{
  float4 pos : SV_POSITION;
  float2 uv  : TEXCOORD0;
  float4 col : COLOR0;
};

float4 unpackUnorm4x8(uint col)
{
    float4 result;
    result.x = ((col >> 0)  & 0xFF) / 255.0;
    result.y = ((col >> 8)  & 0xFF) / 255.0;
    result.z = ((col >> 16) & 0xFF) / 255.0;
    result.w = ((col >> 24) & 0xFF) / 255.0;
    return result;
}

VertexOutput VS(VertexInput input)
{
  VertexOutput output;
  output.pos = float4(input.pos, 0.0, 1.0);
  output.uv = input.uv;
  output.col = unpackUnorm4x8(input.col);
  return output;
}
