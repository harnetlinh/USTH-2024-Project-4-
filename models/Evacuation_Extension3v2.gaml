/**
* Name: EvacuationExtension3v2
* Based on the internal empty template. 
* Author: hangoclinh
* Tags: 
*/
model EvacuationExtension3v2

global {
	int population_size <- 1000 parameter: "population size";
	int num_shelter <- 1 parameter: "Number of shelter";
	shape_file shapefile_buildings <- shape_file("../includes/buildings.shp");
	shape_file shapefile_roads <- shape_file("../includes/clean_roads.shp");
	geometry shape <- envelope(shapefile_roads);
	graph road_network;
	float step <- 10 #s;
	list<building> shelters; // List shelters
	map<road, float> new_weights;
	string alertStrategy <- "random";

	init {
		create building from: shapefile_buildings;
		create road from: shapefile_roads;
		road_network <- as_edge_graph(road);
		// sortet buildings by area
		let sorted_buildings <- reverse(building sort_by (each.shape.area));
		loop i from: 0 to: (num_shelter - 1) {
			sorted_buildings[i].isShelter <- true;
		}

		shelters <- building where (each.isShelter);
		let non_shelter_buildings <- building where (not each.isShelter); // prevent any inhabitant in the shelter
		create inhabitant number: population_size {
			home <- any_location_in(one_of(non_shelter_buildings));
			location <- home;
			let informed_inhabitants <- list(inhabitant where (each.isInformed));
			loop informed_inhabitant over: informed_inhabitants {
				ask informed_inhabitant {
					if (flip(0.1)) {
						isEvacuating <- true;
						building nearestShelter <- one_of(shelters closest_to location);
						if (nearestShelter != nil) {
							target <- nearestShelter.location;
						}

					}

				}

			}

		}
		// Strategy
		switch alertStrategy {
		// random Strategy
			match "random" {
				ask inhabitant {
					if (flip(0.1)) {
						isInformed <- true;
					}

				}

			}
			//	furthest Strategy
			match "furthest" {
				loop i from: 1 to: (length(inhabitant) * 0.1) {
					inhabitant _inh <- (inhabitant where (not each.isInformed)) farthest_to one_of(shelters);
					ask _inh {
						isInformed <- true;
					}

				}

			}
			// closest Strategy
			match "closest" {
				loop i from: 1 to: (length(inhabitant) * 0.1) {
					inhabitant _inh <- (inhabitant where (not each.isInformed)) closest_to one_of(shelters);
					ask _inh {
						isInformed <- true;
					}

				}

			}

			default {
			}

		}

	}

	reflex update_speed {
		ask road {
			speed_rate <- max(exp(-length(inhabitant at_distance 1) / (1 + shape.perimeter / 10)), 0.1);
		}

	}

	reflex simulation_running_condition {
		int remaining_informed <- length(inhabitant where (each.isInformed or each.isEvacuating));
		int remaining_evacuated <- length(inhabitant where (each.isEvacuated));
		// If there is no body know about the infor and evacutation or all inhabitant have been evacuated
		if (remaining_informed = 0 or remaining_evacuated = population_size) {
			do pause;
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
		draw shape + (1 + 5 * (1 - speed_rate)) color: #black;
	}

}

species inhabitant skills: [moving] {
	string mobilityType;
	bool isInformed <- false;
	bool isEvacuating <- false; // Evacuating means that the inhabitant has already known where the Shelter
	bool isEvacuated <- false;
	list<building> listCheckBuilding <- list(building); // to prevent the habitant check same building more than 1 times
	point home;
	point target;
	point location <- home;
	road currentRoad;

	aspect default {
		rgb color;
		if (isEvacuated) {
			color <- #green;
		} else if (isEvacuating) {
			color <- #orange;
		} else if (isInformed) {
			color <- #red;
		} else {
			color <- #cyan;
		}

		draw circle(4) color: color;
	}

	reflex inform_evacuating when: (not isInformed and not isEvacuating and not isEvacuated) {
		list<inhabitant> nearbyEvacuating <- (inhabitant at_distance 10) where (each.isInformed or each.isEvacuating);
		// if an habitant who is not informed near an evacuating inhabitant, he will be informed with 10% chance
		if (length(nearbyEvacuating) > 0 and flip(0.1)) {
			isInformed <- true;
			if (flip(0.1)) { // 10% chance to know where is the shelter
				building nearestShelter <- one_of(shelters closest_to location);
				if (nearestShelter != nil) {
					target <- nearestShelter.location;
					isEvacuating <- true;
					isInformed <- false;
				}

			}

		}

	}

	// informed inhabitant found the shelter
	reflex check_shelter when: isInformed {
		list<building> nearbyShelter <- (building where each.isShelter) at_distance 20;
		if (nearbyShelter != nil and length(nearbyShelter) > 0) {
			isEvacuating <- true;
			isInformed <- false;
			target <- nearbyShelter[0].location;
		} else {
			building randomBuilding <- one_of(listCheckBuilding);
			if (randomBuilding != nil and target = nil) {
				target <- randomBuilding.location;
				remove randomBuilding from: listCheckBuilding;
			}

		}

	}

	reflex just_moving when: target = nil and (not isInformed and not isEvacuating and not isEvacuated) {

	// random moving
		building randomBuilding <- one_of(building where not each.isShelter);
		if (randomBuilding != nil) {
			target <- randomBuilding.location;
		}

	}

	reflex evacuated when: isEvacuated {
		target <- nil;
		isEvacuating <- false;
		isInformed <- false;
	}

	reflex evacuating when: isEvacuating and target = nil {
		isEvacuating <- false;
		isEvacuated <- true;
	}

	reflex update_current_road {
	// Detect the current road of the inhabitant
		list<road> roads_at_location <- list(road where (each overlaps location));
		if (roads_at_location != nil and length(roads_at_location) > 0) {
			currentRoad <- roads_at_location[0]; // 
		}

	}

	reflex move when: ((not isEvacuated) and target != nil) {
		float speedFactor;
		float trafficImpactFactor;
		switch (mobilityType) {
			match "CAR" {
				speedFactor <- 100.0;
				trafficImpactFactor <- 10.0;
			}

			match "MOTORCYCLE" {
				speedFactor <- 85.0;
				trafficImpactFactor <- 20.0;
			}

			default {
				speedFactor <- 10.0; // WALKING
				trafficImpactFactor <- 50.0;
			}

		}

		int trafficDensity <- length(inhabitant where (each.currentRoad = currentRoad));
		float trafficFactor <- trafficImpactFactor / trafficDensity;
		speed <- speedFactor * trafficFactor;
		do goto target: target on: road_network;
		if (location = target) {
			target <- nil;
			if (isEvacuating) {
				isEvacuating <- true;
				isInformed <- false;
			}

		}

	} }

experiment EvacuationExperiment type: gui parallel: true {
	output {
		display PopulationMap type: opengl {
			species building;
			species road;
			species inhabitant aspect: default;
		}

		monitor "Evacuating Population" value: length(inhabitant where (each.isEvacuating));
		monitor "Informed Population" value: length(inhabitant where (each.isInformed));
		monitor "Not Informed Population" value: length(inhabitant where (not each.isInformed and not each.isEvacuating and not each.isEvacuated));
		monitor "Evacuated Population" value: length(inhabitant where (each.isEvacuated));
		monitor "Number of Shelter" value: length(building where (each.isShelter));
	}

	init {
		create simulation with: [alertStrategy::"random", name:: "RandomAlert"];
		create simulation with: [alertStrategy::"furthest", name:: "FurthestAlert"];
		create simulation with: [alertStrategy::"closest", name:: "ClosestAlert"];
	}

}

experiment BatchEvacuation type: batch until: (length(inhabitant where (each.isEvacuated)) = population_size) or length(inhabitant where (not each.isInformed or
each.isEvacuating)) = 0 {
	method exploration with: [["alertStrategy"::"random"], ["alertStrategy"::"furthest"], ["alertStrategy"::"closest"]];
	parameter "Alert Strategy" var: alertStrategy category: "Initial Conditions" among: ["random", "furthest", "closest"];
	parameter "Population Size" var: population_size category: "Initial Conditions" min: 100 max: 2000 step: 100;
	parameter "Alert Time Before Flooding" var: step category: "Initial Conditions" min: 5 max: 60 step: 5;

	reflex end_of_simulation {
		int cpt <- 0;
		int totalEvacuated <- length(inhabitant where each.isEvacuated);
		int totalTimeSpent <- cycle;
		save [totalEvacuated, totalTimeSpent] to: "Result/output_file.csv" format: csv;
	}

	permanent {
		display Comparison type: 2d {
			chart "Number of Inhabitant" type: series {
				data "Evacuated Inhabitant" value: length(inhabitant where each.isEvacuated) style: spline color: #blue;
			}

		}

	}

}
	




