/**
* Name: Evacuation
* Based on the internal empty template. 
* Author: hangoclinh
* Tags: 
*/
model Evacuation

/* Insert your model definition here */
global {
	int population_size <- 1000;
	geometry shelter_location; // Define the location of the shelter
	init {
	// Initialize residents and the shelter
	// Randomly inform 10% of the population
	}

}

species resident skills: [moving] {
	bool isInformed <- false;
	bool isEvacuating <- false;
	point home;
	point location <- home;

	reflex check_evacuation {
	// Logic for starting evacuation
	}

	reflex move {
	// Move towards the shelter if evacuating
	}

}

experiment EvacuationExp type: gui {
// Experiment setup and visualization
}