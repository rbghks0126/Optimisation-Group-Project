'data' 
----- part 1: has data files for the run-time comparison section.
- data1: example data 1 provided to us.
- data1_part2: data we used for multiple-services MIP in part 2
- 



'files'
----- 'part1' 
------------ mip_model_part1_final: code for part1, plain MIP. Solves data1 in the 'data' folder.
------------ part1_heuristic: code for heuristic, solving data_numP100_numC25_10_05_23_17 in data/part1.
			      At the end, 'dict' contains all the routes of providers.

----- 'part2' 
------------ mip_model_part1_final: code for hourly pay extension. Solves data1 in the 'data' folder. Just the objective is changed from mip_model_part1_final.
------------ part2_matheheuristics: code for matheheuristic. Solves data_numP100_numC25_10_05_23_17 in data/part1.
				    Runs the heuristic. Feeds in the solution ('dict') as initial x values for the MIP.
------------ part2_late_penalty: code for the late hour penalty extension. Solves data2_simplified2 in 'data' folder.
------------ part2_service_type: code for multiple-services model. Solves data1_part2 in 'data' folder. 


'problem generation'
----- workflow_generating instances.ipynb: python jupyter notebook showing the workflow for generating new random problem instance.
----- generate_instance: python supplementary code that is imported in workflow_generating instances.ipynb.

'python'
----- draw directed graph.ipynb: Draw a visualisation of the routes.  