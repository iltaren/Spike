#include "SpikingNeurons.h"
#include <stdlib.h>
#include "CUDAErrorCheckHelpers.h"


// SpikingNeurons Constructor
SpikingNeurons::SpikingNeurons() {
	states_v = NULL;
	states_u = NULL;
	param_c = NULL;
	param_d = NULL;

	d_states_v = NULL;
	d_states_u = NULL;
	d_param_c = NULL;
	d_param_d = NULL;
}


// SpikingNeurons Destructor
SpikingNeurons::~SpikingNeurons() {

}


int SpikingNeurons::AddGroupNew(neuron_struct *params, int group_shape[2]){
	
	int new_group_id = Neurons::AddGroupNew(params, group_shape);

	states_v = (float*)realloc(states_v, (total_number_of_neurons*sizeof(float)));
	states_u = (float*)realloc(states_u, (total_number_of_neurons*sizeof(float)));
	param_c = (float*)realloc(param_c, (total_number_of_neurons*sizeof(float)));
	param_d = (float*)realloc(param_d, (total_number_of_neurons*sizeof(float)));

	return new_group_id;
}


void SpikingNeurons::initialise_device_pointersNew() {

	CudaSafeCall(cudaMalloc((void **)&d_lastspiketime, sizeof(float)*total_number_of_neurons));

	CudaSafeCall(cudaMalloc((void **)&d_states_v, sizeof(float)*total_number_of_neurons));
 	CudaSafeCall(cudaMalloc((void **)&d_states_u, sizeof(float)*total_number_of_neurons));
 	CudaSafeCall(cudaMalloc((void **)&d_param_c, sizeof(float)*total_number_of_neurons));
 	CudaSafeCall(cudaMalloc((void **)&d_param_d, sizeof(float)*total_number_of_neurons));


	SpikingNeurons::reset_neuron_variables_and_spikesNew();
}

void SpikingNeurons::reset_neuron_variables_and_spikesNew() {

	CudaSafeCall(cudaMemset(d_lastspiketime, -1000.0f, total_number_of_neurons*sizeof(float)));

	CudaSafeCall(cudaMemcpy(d_states_v, states_v, sizeof(float)*total_number_of_neurons, cudaMemcpyHostToDevice));
	CudaSafeCall(cudaMemcpy(d_states_u, states_u, sizeof(float)*total_number_of_neurons, cudaMemcpyHostToDevice));
	CudaSafeCall(cudaMemcpy(d_param_c, param_c, sizeof(float)*total_number_of_neurons, cudaMemcpyHostToDevice));
	CudaSafeCall(cudaMemcpy(d_param_d, param_d, sizeof(float)*total_number_of_neurons, cudaMemcpyHostToDevice));
	
}





__global__ void spikingneurons2(float *d_states_v,
								float *d_states_u,
								float *d_param_c,
								float *d_param_d,
								float* d_lastspiketime,
								float currtime,
								size_t total_number_of_neurons);


void SpikingNeurons::spikingneurons_wrapper(float currtime) {

	spikingneurons2<<<number_of_neuron_blocks_per_grid, threads_per_block>>>(d_states_v,
																	d_states_u,
																	d_param_c,
																	d_param_d,
																	d_lastspiketime,
																	currtime,
																	total_number_of_neurons);

	CudaCheckError();
}


// Spiking Neurons
__global__ void spikingneurons2(float *d_states_v,
								float *d_states_u,
								float *d_param_c,
								float *d_param_d,
								float* d_lastspiketime,
								float currtime,
								size_t total_number_of_neurons) {

	// Get thread IDs
	int idx = threadIdx.x + blockIdx.x * blockDim.x;
	if (idx < total_number_of_neurons) {
		// First checking if neuron has spiked:
		if (d_states_v[idx] >= 30.0f){
			// Reset the values of these neurons
			d_states_v[idx] = d_param_c[idx];
			d_states_u[idx] += d_param_d[idx];
			// Update the last spike times of these neurons
			d_lastspiketime[idx] = currtime;
		}
	}
	__syncthreads();

}