

/**
* Name: Evacuation
* Based on the internal empty template. 
* Author: hangoclinh
* Tags: 
*/
model Evacuation

global {
	int population_size <- 1000 parameter: "population size";
	shape_file shapefile_buildings <- shape_file("../includes/buildings.shp");
	shape_file shapefile_roads <- shape_file("../includes/clean_roads.shp");
	geometry shape <- envelope(shapefile_roads);
	graph road_network;
	float step <- 10 #s;
	building shelter;

	init {
		create building from: shapefile_buildings;
		create road from: shapefile_roads;
		road_network <- as_edge_graph(road);
		shelter <- one_of(building where (each.height = max(building collect each.height)));
		ask shelter {
			isShelter <- true;
		}

		create inhabitant number: population_size {
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
		draw shape color: (isShelter ? #gold : #gray);
	}

}

species road {
	float speed_rate;

	aspect default {
		draw shape color: #black;
	}

}

species inhabitant skills: [moving] {
	bool isInformed <- false;
	bool isEvacuating <- false;
	point home;
	point location <- home;

	aspect default {
		draw circle(5) color: color;
	}

	reflex observe_and_evacuate {
		list<inhabitant> nearbyEvacuatingPeople <- list(inhabitant at_distance 10) where (each.isEvacuating);
		if (isInformed and not isEvacuating) {
			isEvacuating <- true;
			do goto target: shelter.location on: road_network;
		} else if (not isInformed) {
			if (length(nearbyEvacuatingPeople) > 0 and flip(0.1)) {
				isInformed <- true;
				isEvacuating <- true;
				do goto target: shelter.location on: road_network;
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

		monitor "Evacuated Population" value: length(inhabitant where (each.isEvacuating));
		monitor "Informed Population" value: length(inhabitant where (each.isInformed));
	}

}