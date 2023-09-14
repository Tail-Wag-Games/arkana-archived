out vec4 position;
out vec4 light_position;
out vec3 normal;
out vec4 color;
out vec3 material;

void skinned_pos_nrm(in vec4 pos, in vec4 nrm, in vec4 skin_weights, in vec4 skin_indices, in vec2 u_joint_uv, out vec4 skin_pos, out vec4 skin_nrm) {
    skin_pos = vec4(0.0, 0.0, 0.0, 1.0);
    skin_nrm = vec4(0.0, 0.0, 0.0, 0.0);    
    vec4 weights = skin_weights / dot(skin_weights, vec4(1.0));
    vec2 step = vec2(u_joint_pixel_width, 0.0);
    vec2 uv;
    vec4 xxxx, yyyy, zzzz;

    if (skin_weights.x <= 0.0 && skin_weights.y <= 0.0 && skin_weights.z <= 0.0 && skin_weights.w <= 0.0) {
        skin_pos = pos;
        skin_nrm = nrm;
        return;
    }

    if (weights.x > 0.0) {
        uv = vec2(u_joint_uv.x + (3.0 * skin_indices.x)*u_joint_pixel_width, u_joint_uv.y);
        xxxx = textureLod(u_joint_tex, uv, 0.0);
        yyyy = textureLod(u_joint_tex, uv + step, 0.0);
        zzzz = textureLod(u_joint_tex, uv + 2.0 * step, 0.0);
        skin_pos.xyz += vec3(dot(pos,xxxx), dot(pos,yyyy), dot(pos,zzzz)) * weights.x;
        skin_nrm.xyz += vec3(dot(nrm,xxxx), dot(nrm,yyyy), dot(nrm,zzzz)) * weights.x;
    }
    if (weights.y > 0.0) {
        uv = vec2(u_joint_uv.x + (3.0 * skin_indices.y)*u_joint_pixel_width, u_joint_uv.y);
        xxxx = textureLod(u_joint_tex, uv, 0.0);
        yyyy = textureLod(u_joint_tex, uv + step, 0.0);
        zzzz = textureLod(u_joint_tex, uv + 2.0 * step, 0.0);
        skin_pos.xyz += vec3(dot(pos,xxxx), dot(pos,yyyy), dot(pos,zzzz)) * weights.y;
        skin_nrm.xyz += vec3(dot(nrm,xxxx), dot(nrm,yyyy), dot(nrm,zzzz)) * weights.y;
    }
    if (weights.z > 0.0) {
        uv = vec2(u_joint_uv.x + (3.0 * skin_indices.z)*u_joint_pixel_width, u_joint_uv.y);
        xxxx = textureLod(u_joint_tex, uv, 0.0);
        yyyy = textureLod(u_joint_tex, uv + step, 0.0);
        zzzz = textureLod(u_joint_tex, uv + 2.0 * step, 0.0);
        skin_pos.xyz += vec3(dot(pos,xxxx), dot(pos,yyyy), dot(pos,zzzz)) * weights.z;
        skin_nrm.xyz += vec3(dot(nrm,xxxx), dot(nrm,yyyy), dot(nrm,zzzz)) * weights.z;
    }
    if (weights.w > 0.0) {
        uv = vec2(u_joint_uv.x + (3.0 * skin_indices.w)*u_joint_pixel_width, u_joint_uv.y);
        xxxx = textureLod(u_joint_tex, uv, 0.0);
        yyyy = textureLod(u_joint_tex, uv + step, 0.0);
        zzzz = textureLod(u_joint_tex, uv + 2.0 * step, 0.0);
        skin_pos.xyz += vec3(dot(pos,xxxx), dot(pos,yyyy), dot(pos,zzzz)) * weights.w;
        skin_nrm.xyz += vec3(dot(nrm,xxxx), dot(nrm,yyyy), dot(nrm,zzzz)) * weights.w;
    }
}

void main() {
  vec4 pos, nrm;
  skinned_pos_nrm(v_position, vec4(v_normal, 0.0), jweights, jindices * 255.0, u_joint_uv, pos, nrm);

  if (jweights.x <= 0.0 && jweights.y <= 0.0 && jweights.z <= 0.0 && jweights.w <= 0.0) {
    gl_Position = u_mat_vp * i_mat_m * v_position;
    light_position = u_light_vp * i_mat_m * v_position;
    position = (i_mat_m * v_position);
    normal = (i_mat_m * vec4(-v_normal, 0.0)).xyz;
  } else {
    // mat4 trans_i_mat_m = transpose(i_mat_m);
    pos = vec4(dot(pos,vec4(25.0, 0.0, 0.0, 0.0)), dot(pos,vec4(0.0, 25.0, 0.0, 0.0)), dot(pos,vec4(0.0, 0.0, -25.0, -25.0)), 1.0);
    nrm = vec4(dot(nrm,vec4(25.0, 0.0, 0.0, 0.0)), dot(nrm,vec4(0.0, 25.0, 0.0, 0.0)), dot(nrm,vec4(0.0, 0.0, -25.0, -25.0)), 0.0);
    
    gl_Position = u_mat_vp * pos;
    light_position = u_light_vp * pos;
    position = pos;
    normal = -nrm.xyz;
  }
  
  color = vec4(i_color, 0.0);
  material = i_material;
}
