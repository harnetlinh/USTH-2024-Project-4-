/**
* Name: EvacuationExtension3
* Based on the internal empty template. 
* Author: hangoclinh
* Tags: 
*/
model EvacuationExtension3

global {
	int population_size <- 1000 parameter: "population size";
	int num_shelter <- 5 parameter: "Number of shelter";
	shape_file shapefile_buildings <- shape_file("../includes/buildings.shp");
	shape_file shapefile_roads <- shape_file("../includes/clean_roads.shp");
	geometry shape <- envelope(shapefile_roads);
	graph road_network;
	float step <- 10 #s;
	list<building> shelters; // list shelter
	init {
		create building from: shapefile_buildings;
		create road from: shapefile_roads;
		road_network <- as_edge_graph(road);

		// random pick a building to be a shelter
		loop i from: 1 to: num_shelter {
			ask one_of(building) {
				isShelter <- true;
			}

		}

		shelters <- building where (each.isShelter);
		create inhabitant number: population_size {
			float rand <- rnd(100);
			if (rand < 20) {
				mobilityType <- "CAR";
			} else if (rand < 90) {
				mobilityType <- "MOTORCYCLE";
			} else {
				mobilityType <- "WALKING";
			}

			home <- any_location_in(one_of(building));
			location <- home;
			isInformed <- flip(0.1);
		}

	}

	reflex update_speed {
		ask road {
			speed_rate <- max(exp(-length(inhabitant at_distance 1) / (1 + shape.perimeter / 10)), 0.1);
		}

	}

}

species building {
	int height;
	bool isShelter <- false;

	aspect default {
		if (isShelter) {
			draw circle(20) color: #green;
		} else {
			draw shape color: #gray;
		}

	}

}

species road {
	float speed_rate;
	int nb_inhabitants <- 0 update: length(inhabitant at_distance 1);

	reflex update_speed_rate {
		speed_rate <- max(exp(-nb_inhabitants / (1 + shape.perimeter / 10)), 0.1);
	}

	aspect default {
		draw shape + (1 + 5 * (1 - speed_rate)) color: #red;
	}

}

species inhabitant skills: [moving] {
	string mobilityType;
	bool isInformed <- false;
	bool isEvacuating <- false;
	point home;
	point target;
	point location <- home;

	aspect default {
		rgb color <- isInformed ? (isEvacuating ? #orange : #green) : #purple;
		draw circle(5) color: color;
	}

	reflex update_status {
		if (isInformed and not isEvacuating) {
			isEvacuating <- true;
			building nearestShelter <- one_of(shelters closest_to location);
			if (nearestShelter != nil) {
				target <- nearestShelter.location;
			}

		} else if (not isInformed) {
			list<inhabitant> nearbyEvacuating <- list(inhabitant at_distance 10) where (each.isEvacuating);
			if (length(nearbyEvacuating) > 0 and flip(0.1)) {
				isInformed <- true;
				isEvacuating <- true;
				building nearestShelter <- one_of(shelters closest_to location);
				if (nearestShelter != nil) {
					target <- nearestShelter.location;
				}

			}

		}

	}

	reflex decise_target when: target = nil {
	// if inhabitant is informed or evacuating, he will go directly to the closest shelter
		if (isInformed and isEvacuating) {
			building nearestShelter <- one_of(shelters closest_to location);
			if (nearestShelter != nil) {
				target <- nearestShelter.location;
			}

		} else {
		// If he has not be informed and not evacuating, he will random check a building if it is a shelter or not
			building randomBuilding <- one_of(building);
			if (randomBuilding != nil) {
				target <- randomBuilding.location;
			}

			// check if the shelter is close to him (20m)
			list<building> nearbyShelters <- list(building at_distance 10) where (each.isShelter);
			if (nearbyShelters != nil) {
				if (length(nearbyShelters) > 0) {
					isInformed <- true;
					isEvacuating <- true;
					target <- one_of(nearbyShelters).location;
				}

			}

		}

	}

	reflex move {
		if ((isEvacuating or (not isInformed)) and target != nil) {
			float speedFactor;
			switch (mobilityType) {
				match "CAR" {
					speedFactor <- 1.0;
				}

				match "MOTORCYCLE" {
					speedFactor <- 0.85;
				}

				default {
					speedFactor <- 0.1; // WALKING
				}

			}

			// Calculate traffic density
			float trafficDensity <- length(road at_distance 1);
			float trafficImpactFactor <- (mobilityType = "CAR" ? 10 : (mobilityType = "MOTORCYCLE" ? 20 : 50));
			float trafficFactor <- exp(-trafficDensity / trafficImpactFactor);

			// Calculate the final travel speed after adding the traffic jam factor
			speed <- speedFactor * trafficFactor;
			do goto target: target on: road_network;
			if (location = target) {
				target <- nil;
				isEvacuating <- false;
			}

		}

	}

}

experiment EvacuationExperiment type: gui {
	output {
		display PopulationMap type: opengl {
			species building;
			species road;
			species inhabitant aspect: default;
		}

		monitor "Evacuating Population" value: length(inhabitant where (each.isEvacuating));
		monitor "Informed Population" value: length(inhabitant where (each.isInformed));
		monitor "Not Informed Population" value: length(inhabitant where (not each.isInformed));
		monitor "Evacuated Population" value: length(inhabitant where (each.isInformed and (not each.isEvacuating)));
		monitor "Number of Shelter" value: length(building where (each.isShelter));
		monitor "Number of Car" value: length(inhabitant where (each.mobilityType = 'CAR'));
		monitor "Number of Motobile" value: length(inhabitant where (each.mobilityType = 'MOTORCYCLE'));
		monitor "Number of Pedestrians" value: length(inhabitant where (each.mobilityType = 'WALKING'));
	}

}


