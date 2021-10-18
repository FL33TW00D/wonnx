{% include "structs.wgsl" %}

[[group(0), binding({{ bindings[0].counter }})]]
var<storage, read_write> var_{{ bindings[0].tensor }}: Array;

[[group(0), binding({{ bindings[1].counter }})]]
var<storage, read_write> var_{{ bindings[1].tensor }}: Array;

{% if input | length == 3 %} // Bias
[[group(0), binding({{ bindings[2].counter }})]]
var<storage, read_write> var_{{ bindings[2].tensor }}: ArrayVector;
{% endif %}  

[[group(0), binding({{ bindings[3].counter }})]]
var<storage, read_write> var_{{ bindings[3].tensor }}: Array;

[[stage(compute), workgroup_size(1)]]
fn main([[builtin(global_invocation_id)]] global_id: vec3<u32>) {
	let gidx = global_id.x;
	let batch_number = gidx / {{ M_x_H_x_W / 4 }}u; 
	let rest = gidx % {{ M_x_H_x_W / 4 }}u; 

        let m = rest / {{ H_x_W }}u;
        let rest = rest % {{ H_x_W }}u;
        
        let y = rest / {{ width }}u;
        let x = rest % {{ width }}u;
        
        var result = vec4<f32>(0., 0., 0., 0.);
        
        let root_index = batch_number * {{ original_C_x_H_x_W }}u;
        let root_kernel_index = m * {{ kernel_channel_len * 4 }}u;

        for(var c: u32 = 0u; c < {{ channel }}u; c = c + 1u) {
            
            let base_index = root_index + c * {{ original_H_x_W }}u;
            let base_kernel_index = root_kernel_index + c * {{ kernel_len }}u;

            for(var i: u32 = 0u; i < {{ kernel_shape[0] }}u; i = i + 1u) {

                var tmp_vec = vec3<f32>(0., 0., 0.);

                var kernel_vector_0 = vec3<f32>(0., 0., 0.);
                var kernel_vector_1 = vec3<f32>(0., 0., 0.);
                var kernel_vector_2 = vec3<f32>(0., 0., 0.);
                var kernel_vector_3 = vec3<f32>(0., 0., 0.);

		let tmp_y = y * {{ stride[0] }}u + i * {{ dilation[0] }}u - {{ pad[0] }}u; 

        	if ((tmp_y < {{ original_height }}u) && (tmp_y >= 0u)) {
        
	        for(var j: u32 = 0u; j < {{ kernel_shape[1] }}u; j = j + 1u) { 

                        let tmp_x = x * {{ stride[1] }}u + j * {{ dilation[1] }}u - {{ pad[1] }}u;

                        if ((tmp_x < {{ original_width }}u) && (tmp_x >= 0u)) {

                                let tmp_index = base_index + tmp_y * {{ original_width }}u + tmp_x;
                                let index_kernel = base_kernel_index + i * {{ kernel_shape[1] }}u + j;
                                
                                tmp_vec[j] = var_{{ input[0] }}.data[tmp_index];

                                kernel_vector_0[j] = var_{{ input[1] }}.data[index_kernel];
                                kernel_vector_1[j] = var_{{ input[1] }}.data[index_kernel + {{ kernel_channel_len }}u];
                                kernel_vector_2[j] = var_{{ input[1] }}.data[index_kernel + {{ kernel_channel_len * 2 }}u];
                                kernel_vector_3[j] = var_{{ input[1] }}.data[index_kernel + {{ kernel_channel_len * 3 }}u];
				
                        }
  	        }
		}
               result = tmp_vec * mat4x3<f32>(
                       kernel_vector_0,
                       kernel_vector_1,
                       kernel_vector_2,
                       kernel_vector_3,
               ) + result;
            }

        }       
	

{% if op_type is matching("convrelu") %}
        result = max(result{% if input | length == 3 %} + var_{{ input[2] }}.data[m]{% endif %}, vec4<f32>(0., 0., 0., 0.));
{% else %}
        {% if input | length == 3 %}result = result + var_{{ input[2] }}.data[m]{% endif %};
{% endif %}

        let base_index = batch_number * {{ M_x_H_x_W }}u + m * {{ H_x_W * 4 }}u + y * {{ width }}u + x;
        for(var index_vec: u32 = 0u; index_vec < 4u; index_vec = index_vec + 1u) {
                let index = base_index + index_vec * {{ H_x_W }}u;

                var_{{ output[0] }}.data[index] = result[index_vec];
        }
}
