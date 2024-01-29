

/**
* Name: Evacuation
* Based on the internal empty template. 
* Author: hangoclinh
* Tags: 
*/
model Evacuation

global {
	int population_size <- 1000 parameter: "Population Size";
	float evacuationRadius <- 10.0 parameter: "Evacuation Observation Radius";
	float evacuationProbability <- 0.1 parameter: "Evacuation Probability upon Observation";
	int evacuated_population <- 0;
	geometry shelter_location; // Define the location of the largest building as a shelter
	init {
	// Initialize the building and road network
	// Assume the shelter_location is defined here

	// Create inhabitants
		create inhabitant number: population_size {
			home <- one_of(building).location; // Assuming buildings are defined
			location <- home;
			isInformed <- flip(0.1); // 10% of the population is initially informed
		}

	}

	reflex update_simulation {
		evacuated_population <- length(inhabitant where (each.isInformed and each.location = shelter_location));
		if (evacuated_population = population_size) {
			do pause;
		}

	}

}

species building {
	geometry shape;
	int height;

	aspect default {
		draw shape color: #gray;
	}

}

species inhabitant skills: [moving] {
	bool isInformed <- false;
	bool isEvacuating <- false;
	point home;
	point location <- home;

	aspect default {
		draw circle(5) color: isInformed ? #blue : #gray;
	}

	reflex check_evacuation {
		if (isInformed and not isEvacuating) {
			isEvacuating <- true;
			do goto target: shelter_location;
		} else if (not isInformed) {
			ask inhabitant at_distance evacuationRadius where (each.isEvacuating) {
				if (flip(evacuationProbability)) {
					isInformed <- true;
					isEvacuating <- true;
					do goto target: shelter_location;
					return;
				}

			}

		}

	}

}

experiment EvacuationExperiment type: gui {
	parameter "Population Size" var: population_size category: "Setup" min: 100 max: 10000;
	parameter "Evacuation Observation Radius" var: evacuationRadius category: "Behavior" min: 1 max: 20;
	parameter "Evacuation Probability upon Observation" var: evacuationProbability category: "Behavior" min: 0.0 max: 1.0;
	output {
		display PopulationMap type: opengl {
			species inhabitant aspect: default;
			species building; // Assuming building species is defined
			// Additional visualization elements
		}

		display EvacuationStats type: 2d {
			chart "Evacuation Status" type: series {
				data "Informed" value: length(inhabitant where (each.isInformed));
				data "Evacuated" value: evacuated_population;
				data "Total Population" value: population_size;
			}

		}

	}

}
