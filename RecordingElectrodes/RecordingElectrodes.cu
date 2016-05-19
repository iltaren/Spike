//	RecordingElectrodes Class C++
//	RecordingElectrodes.cu
//
//  Adapted from CUDACode
//	Authors: Nasir Ahmad and James Isbister
//	Date: 9/4/2016

#include "RecordingElectrodes.h"
#include <stdlib.h>
#include <iostream>
#include <stdio.h>
#include <fstream>
#include "../Helpers/CUDAErrorCheckHelpers.h"
#include "../Helpers/TerminalHelpers.h"
#include <string>
using namespace std;

const string RESULTS_DIRECTORY ("Results/");


// RecordingElectrodes Constructor
RecordingElectrodes::RecordingElectrodes(SpikingNeurons * neurons_parameter, const char * prefix_string_param) {

	neurons = neurons_parameter;
	prefix_string = prefix_string_param;

	d_per_neuron_spike_counts = NULL;

	d_tempstorenum = NULL;
	d_tempstoreID = NULL;
	d_tempstoretimes = NULL;

	h_tempstoreID = NULL;
	h_tempstoretimes = NULL;
	h_temp_total_number_of_spikes = NULL;
	h_spikestoreID = NULL;
	h_spikestoretimes = NULL;
	h_total_number_of_spikes = 0;

}


// RecordingElectrodes Destructor
RecordingElectrodes::~RecordingElectrodes() {

	CudaSafeCall(cudaFree(d_tempstorenum));
	CudaSafeCall(cudaFree(d_tempstoreID));
	CudaSafeCall(cudaFree(d_tempstoretimes));

	free(h_tempstoreID);
	free(h_tempstoretimes);
	free(h_temp_total_number_of_spikes);
	free(h_spikestoreID);
	free(h_spikestoretimes);

}


void RecordingElectrodes::initialise_device_pointers() {

	//For counting spikes
	CudaSafeCall(cudaMalloc((void **)&d_per_neuron_spike_counts, sizeof(int) * neurons->total_number_of_neurons));
	CudaSafeCall(cudaMemset(d_per_neuron_spike_counts, 0, sizeof(int) * neurons->total_number_of_neurons));

	// For saving spikes (Make seperate class)
	CudaSafeCall(cudaMalloc((void **)&d_tempstoreID, sizeof(int)*(neurons->total_number_of_neurons)));
	CudaSafeCall(cudaMalloc((void **)&d_tempstoretimes, sizeof(float)*(neurons->total_number_of_neurons)));
	CudaSafeCall(cudaMalloc((void **)&d_tempstorenum, sizeof(int)));

	// Send data to device: data for saving spikes
	CudaSafeCall(cudaMemset(d_tempstoreID, -1, sizeof(int)*(neurons->total_number_of_neurons)));
	CudaSafeCall(cudaMemset(d_tempstoretimes, -1.0f, sizeof(float)*(neurons->total_number_of_neurons)));
	CudaSafeCall(cudaMemset(d_tempstorenum, 0, sizeof(int)));
}

void RecordingElectrodes::initialise_host_pointers() {

	h_tempstoreID = (int*)malloc(sizeof(int)*(neurons->total_number_of_neurons));
	h_tempstoretimes = (float*)malloc(sizeof(float)*(neurons->total_number_of_neurons));

	h_temp_total_number_of_spikes = (int*)malloc(sizeof(int));
	h_temp_total_number_of_spikes[0] = 0;
}

void RecordingElectrodes::save_spikes_to_host(float current_time_in_seconds, int timestep_index, int number_of_timesteps_per_epoch) {

	// printf("Save spikes to host. total_number_of_neurons = %d.\n", neurons->total_number_of_neurons);

	// Storing the spikes that have occurred in this timestep

	spikeCollect<<<neurons->number_of_neuron_blocks_per_grid, neurons->threads_per_block>>>(neurons->d_last_spike_time_of_each_neuron,
														d_tempstorenum,
														d_tempstoreID,
														d_tempstoretimes,
														current_time_in_seconds,
														neurons->total_number_of_neurons);

	CudaCheckError();



	if (((timestep_index % 1) == 0) || (timestep_index == (number_of_timesteps_per_epoch-1))){

		// Finally, we want to get the spikes back. Every few timesteps check the number of spikes:
		CudaSafeCall(cudaMemcpy(&(h_temp_total_number_of_spikes[0]), &(d_tempstorenum[0]), (sizeof(int)), cudaMemcpyDeviceToHost));

		// Ensure that we don't have too many
		// if (h_temp_total_number_of_spikes[0] > neurons->total_number_of_neurons){
		// 	print_message_and_exit("Spike recorder has been overloaded! Reduce threshold.");
		// }

		// Deal with them!
		if ((h_temp_total_number_of_spikes[0] >= (0.25*neurons->total_number_of_neurons)) ||  (timestep_index == (number_of_timesteps_per_epoch - 1))){

			// Allocate some memory for them:
			h_spikestoreID = (int*)realloc(h_spikestoreID, sizeof(int)*(h_total_number_of_spikes + h_temp_total_number_of_spikes[0]));
			h_spikestoretimes = (float*)realloc(h_spikestoretimes, sizeof(float)*(h_total_number_of_spikes + h_temp_total_number_of_spikes[0]));
			// Copy the data from device to host
			CudaSafeCall(cudaMemcpy(h_tempstoreID, 
									d_tempstoreID, 
									(sizeof(int)*(neurons->total_number_of_neurons)), 
									cudaMemcpyDeviceToHost));
			CudaSafeCall(cudaMemcpy(h_tempstoretimes, 
									d_tempstoretimes, 
									sizeof(float)*(neurons->total_number_of_neurons), 
									cudaMemcpyDeviceToHost));
			// Pop all of the times where they need to be:
			for (int l = 0; l < h_temp_total_number_of_spikes[0]; l++){
				h_spikestoreID[h_total_number_of_spikes + l] = h_tempstoreID[l];
				h_spikestoretimes[h_total_number_of_spikes + l] = h_tempstoretimes[l];
			}
			// Reset the number on the device
			CudaSafeCall(cudaMemset(&(d_tempstorenum[0]), 0, sizeof(int)));
			CudaSafeCall(cudaMemset(d_tempstoreID, -1, sizeof(int)*neurons->total_number_of_neurons));
			CudaSafeCall(cudaMemset(d_tempstoretimes, -1.0f, sizeof(float)*neurons->total_number_of_neurons));
			// Increase the number on host
			h_total_number_of_spikes += h_temp_total_number_of_spikes[0];
			h_temp_total_number_of_spikes[0] = 0;
		}
	}
}


void RecordingElectrodes::add_spikes_to_per_neuron_spike_count(float current_time_in_seconds) {
	add_spikes_to_per_neuron_spike_count_kernal<<<neurons->number_of_neuron_blocks_per_grid, neurons->threads_per_block>>>(neurons->d_last_spike_time_of_each_neuron,
														d_per_neuron_spike_counts,
														current_time_in_seconds,
														neurons->total_number_of_neurons);
}




void RecordingElectrodes::write_spikes_to_file(Neurons *neurons, int epoch_number) {
	// Get the names
	string file = RESULTS_DIRECTORY + prefix_string + "_Epoch" + to_string(epoch_number) + "_";

	// Open the files
	ofstream spikeidfile, spiketimesfile;
	spikeidfile.open((file + "SpikeIDs.bin"), ios::out | ios::binary);
	spiketimesfile.open((file + "SpikeTimes.bin"), ios::out | ios::binary);
	

	// Send the data
	// spikeidfile.write((char *)h_spikestoreID, h_total_number_of_spikes*sizeof(int));
	// spiketimesfile.write((char *)h_spikestoretimes, h_total_number_of_spikes*sizeof(float));

	for (int i = 0; i < h_total_number_of_spikes; i++) {
		spikeidfile << to_string(h_spikestoreID[i]) << endl;
		spiketimesfile << to_string(h_spikestoretimes[i]) << endl;
	}

	// Close the files
	spikeidfile.close();
	spiketimesfile.close();

	// Reset the spike store
	// Host values
	h_total_number_of_spikes = 0;
	h_temp_total_number_of_spikes[0] = 0;
	// Free/Clear Device stuff
	// Reset the number on the device
	CudaSafeCall(cudaMemset(&(d_tempstorenum[0]), 0, sizeof(int)));
	CudaSafeCall(cudaMemset(d_tempstoreID, -1, sizeof(int)*neurons->total_number_of_neurons));
	CudaSafeCall(cudaMemset(d_tempstoretimes, -1.0f, sizeof(float)*neurons->total_number_of_neurons));
	// Free malloced host stuff
	free(h_spikestoreID);
	free(h_spikestoretimes);
	h_spikestoreID = NULL;
	h_spikestoretimes = NULL;
}



__global__ void add_spikes_to_per_neuron_spike_count_kernal(float* d_last_spike_time_of_each_neuron,
								int* d_per_neuron_spike_counts,
								float current_time_in_seconds,
								size_t total_number_of_neurons) {

	int idx = threadIdx.x + blockIdx.x * blockDim.x;
	while (idx < total_number_of_neurons) {

		if (d_last_spike_time_of_each_neuron[idx] == current_time_in_seconds) {
			atomicAdd(&d_per_neuron_spike_counts[idx], 1);
		}

		// if (idx == 1000) printf("d_per_neuron_spike_counts[idx]: %d\n", d_per_neuron_spike_counts[idx]);
		idx = blockDim.x * gridDim.x;
	}


}

// Collect Spikes
__global__ void spikeCollect(float* d_last_spike_time_of_each_neuron,
								int* d_tempstorenum,
								int* d_tempstoreID,
								float* d_tempstoretimes,
								float current_time_in_seconds,
								size_t total_number_of_neurons){

	int idx = threadIdx.x + blockIdx.x * blockDim.x;
	while (idx < total_number_of_neurons) {

		// If a neuron has fired
		if (d_last_spike_time_of_each_neuron[idx] == current_time_in_seconds) {
			// Increase the number of spikes stored
			int i = atomicAdd(&d_tempstorenum[0], 1);
			// In the location, add the id and the time
			d_tempstoreID[i] = idx;
			d_tempstoretimes[i] = current_time_in_seconds;
		}
		idx = blockDim.x * gridDim.x;

	}
	__syncthreads();
}



void RecordingElectrodes::write_initial_synaptic_weights_to_file(SpikingSynapses *synapses) {
	ofstream initweightfile;
	initweightfile.open(RESULTS_DIRECTORY + prefix_string + "_NetworkWeights_Initial.bin", ios::out | ios::binary);
	initweightfile.write((char *)synapses->synaptic_efficacies_or_weights, synapses->total_number_of_synapses*sizeof(float));
	initweightfile.close();
}


void RecordingElectrodes::save_network_state(SpikingSynapses *synapses) {

	#ifndef QUIETSTART
	printf("Outputting binary files.\n");
	#endif

	// Copy back the data that we might want:
	CudaSafeCall(cudaMemcpy(synapses->synaptic_efficacies_or_weights, synapses->d_synaptic_efficacies_or_weights, sizeof(float)*synapses->total_number_of_synapses, cudaMemcpyDeviceToHost));
	// Creating and Opening all the files
	ofstream synapsepre, synapsepost, weightfile, delayfile;
	weightfile.open(RESULTS_DIRECTORY + prefix_string + "_NetworkWeights.bin", ios::out | ios::binary);
	delayfile.open(RESULTS_DIRECTORY + prefix_string + "_NetworkDelays.bin", ios::out | ios::binary);
	synapsepre.open(RESULTS_DIRECTORY + prefix_string + "_NetworkPre.bin", ios::out | ios::binary);
	synapsepost.open(RESULTS_DIRECTORY + prefix_string + "_NetworkPost.bin", ios::out | ios::binary);
	
	// Writing the data
	weightfile.write((char *)synapses->synaptic_efficacies_or_weights, synapses->total_number_of_synapses*sizeof(float));
	delayfile.write((char *)synapses->delays, synapses->total_number_of_synapses*sizeof(int));
	synapsepre.write((char *)synapses->presynaptic_neuron_indices, synapses->total_number_of_synapses*sizeof(int));
	synapsepost.write((char *)synapses->postsynaptic_neuron_indices, synapses->total_number_of_synapses*sizeof(int));

	// Close files
	weightfile.close();
	delayfile.close();
	synapsepre.close();
	synapsepost.close();
}


