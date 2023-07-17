### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ bb4489cd-e360-40f9-950f-a9029127a97f
begin
    import Pkg
    Pkg.activate("Project.toml")
    using ParticleDA
	using HDF5
    using Random
	using Markdown
    using Plots
    using Statistics
	using PlutoUI
	using LaTeXStrings
	using PlotThemes
	using Plots.PlotMeasures
	using Kroki
	using PlutoLinks: @ingredients
end

# ╔═╡ aae05a0a-4744-47d1-819d-6f1c5bcff6b5
md"""
Theme $(@bind selected_theme Select([:dark => "dark", :default => "default"]))
"""

# ╔═╡ b8026d26-2187-11ee-2234-f523a9788e24
html"<button onclick=present()>Present</button>"

# ╔═╡ 3d919910-a6bc-494d-9268-996fd5e02462
html"""
<h1> 🟢🟣🔴 ParticleDA.jl <br/> <small>Distributed particle filtering in Julia</small></h1>
<br />
<h5>Matt Graham<br /><small>Research Data Scientist @ UCL Advanced Research Computing Centre</small></h5>
"""

# ╔═╡ 452da1fa-dc84-4761-a0d7-8fd2c53647b6
begin
	team_members = Dict{String, String}(
		"Mosè Giordano" => "https://giordano.github.io/img/avatar.jpeg",
		"Tuomas Koskela" => "https://www.ucl.ac.uk/advanced-research-computing/sites/advanced_research_computing/files/styles/non_responsive/public/tuomas_koskela-square-bw.jpeg",
		"Dan Giles" => "https://avatars.githubusercontent.com/u/29146306?v=4",
		"Matt Graham" => "https://matt-graham.github.io/images/profile-photo-mm-graham-small.jpg",
		"Serge Guillas" => "https://www.ucl.ac.uk/advanced-research-computing/sites/advanced_research_computing/files/styles/non_responsive/public/serge_guillas.jpeg",
		"Alex Beskos" => "https://www.turing.ac.uk/sites/default/files/styles/people/public/2018-06/photo.png",
	)
	figures_html = join(
		(
			"""
			<figure style="margin: 0;">
			<img src="$url" style="object-fit: cover; width: 125px; height: 125px;" />
			<p>$name</p>
			</figure>
			"""
			for (name, url) in 
			sort(
				collect(pairs(team_members)), 
				by=name_url -> split(name_url[1])[2]
			)
		), 
		"\n"
	)
	HTML("""
	<h1>👥 Project team</h1>
	
	<div style="margin-top: 20px; display: grid; grid-template-columns: repeat(3, 125px); grid-template-rows: repeat(2, auto); gap: 20px 50px; text-align: center;">
		$(figures_html)
	</div>
	""")
end

# ╔═╡ 488b438e-779a-4259-812d-2e99c6fe1706
md"""
# ❔ Motivation

Assimilating observational data in models of dynamical systems is a vital task in a wide range of applications.

Particle filters allow consistent inference in state space models with non-linear dynamics and non-Gaussian noise distributions.

_However_, there is a lack of robust and easy to use particle filter implementations that are able to be run at scale on high performance computing (HPC) systems.

!!! note
    While particle filters suffer from a 'curse of dimensionality', combining with spatial localisation and tempering approaches can allow scaling to high-dimensional geophysical models.
"""

# ╔═╡ 33aacb01-43e6-4b7d-8950-c7bc72ed323c
md"""
# 🌐 Overview

- ParticleDA.jl is a package for performing particle-filter based data assimilation in Julia.
- The package is open-source and has an extensive suite of tests.
- It provides a simple and well-documented interface for integrating your own models. 
- Currently filters using bootstrap and 'locally optimal' proposals are implemented.
- Supports both distributed and shared-memory parallelism to run at scale on HPC systems.
"""

# ╔═╡ 5e36d92f-db98-4a6a-bb35-c46fab896e34
md"""
# 🔗 Related projects

Open-source projects with similar features in different languages include:

- Parallel Data Assimilation Framework (<https://pdaf.awi.de/>)
  * Fortran90 code base.
  * Long running project with recent GitHub release.
- Parallel Particle Filtering Library (<https://sbalzarini-lab.org/?q=downloads/ppf>)
  * Java code base.
  * Does not appear to be actively developed any more.
"""



# ╔═╡ 7748c722-8be1-4028-aee1-21814da9c7e4
md"""
# 🔤 Particle filtering basics

The _state space model_ formulation, assumes that:
 - the system state dynamics are described by a Markov process - that is the current state depends only on the state at the previous time,
 - our observations of the system depend only on the state at the current time.

!!! note

    An important practical point is that the state dynamics are assumed to be _stochastic_; models with deterministic state dynamics will need to be augmented with stochastic updates.
"""

# ╔═╡ cb7735c5-3fa7-4e40-bcff-be9211497075
md"""
## ⚛️ Particle filters

Particle filters are an algorithm for sequentially estimating the conditional probability distributions on the state given the sequence of observations up to the current time point.

Each distribution is represented by an _ensemble_ of particles, with the algorithm alternating: 
   1. proposing new values and computing corresponding weights for each particle,
   2. resampling the weighted particles to get a new uniformly weighted ensemble.

!!! note
    Step 1 can be performed in parallel for each particle with only step 2 requiring synchronization across particles.
"""

# ╔═╡ 927b3c9c-9c5d-4ed5-9dfd-51c47efeab9a
md"""
## 🦋 Lorenz system particle filtering example

Timestep $(@bind lorenz_filtering_control Slider(1:200; default=1, show_value=false))  
Number particles $(@bind lorenz_n_particle Slider(10:10:100, default=40, show_value=true))
"""

# ╔═╡ cdae6aaa-af2f-420c-8c30-cc2affe87297
htl"""
<h1>Why <img width="200" style="margin-bottom: -25px;" src='https://raw.githubusercontent.com/JuliaLang/julia-logo-graphics/master/images/julia-logo-$(selected_theme == :dark ? "dark" : "color").svg' /> ?
</h1>
"""

# ╔═╡ 266d1b36-7e7d-484f-8802-121839291f29
md"""
## 🗣️ Two language (culture) problem

![](https://cdn.hashnode.com/res/hashnode/image/upload/v1681735971356/91b6e886-7ce1-41a3-9d9f-29b7b096e7f2.png)

Image credit: Matthijs Cox, _The Scientific Coder_ (https://scientificcoder.com/my-target-audience)
"""

# ╔═╡ fdd17edb-8ed7-4399-b14e-7182755f4acd
md"""
## 🌉 Bridging the divide

![](https://cdn.hashnode.com/res/hashnode/image/upload/v1681735992315/62fdd58f-4630-4120-8eb4-5238740543e8.png)

Image credit: Matthijs Cox, _The Scientific Coder_ (https://scientificcoder.com/my-target-audience)
"""

# ╔═╡ 33caa202-a177-47f1-a252-94655c5ff5e2
htl"""
<h2> 
  <img width="24" src="https://raw.githubusercontent.com/JuliaLang/julia-logo-graphics/master/images/julia-dots.svg" />
  Julia
</h2>
"""

# ╔═╡ c110e393-0051-41ab-9381-acfab97d890a
md"""
Julia is a modern, dynamic, general-purpose compiled programming language.

It can be used interactively via a _read evaluate print loop_ (REPL) or notebook like interfaces such as Jupyter or 🎈Pluto (like this presentation!).

The Julia runtime includes a _just-in-time_ (JIT) compiler and garbage collector for automatic memory management.

Multiple dispatch programming paradigm - function behaviour depends on types of all arguments ⟶ simple to write composable and extensible libraries.

"""

# ╔═╡ 35163903-3c2c-4148-bab9-e31d8a9cb0d5
md"""

# 🧑‍💻 Development principles

Emphasis on _robust_, _efficient_ and _general purpose_ implementations rather than algorithmic novelty.

⟶ Trying to do basic things well rather than clever things badly.
"""

# ╔═╡ a1eeb474-d9ad-4f7a-a8e2-9ddb4c526448
md"""
## 📦 Package development

Developed using modern (research) software engineering practices

  * Open source (MIT) licensed with code hosted on GitHub.
  * Collaborative development model with code review.
  * Automated tests, benchmarking and documentation.
  * Releases available from Julia package registry.

!!! tip "Getting involved"
    We are keen to get user feedback and code contributions are also very welcome!
"""

# ╔═╡ 51e87757-885e-4e6c-b940-b829b93d7949
md"""
# ⛓️ Parallelism

A key aim in developing ParticleDA.jl was to allow running particle filter algorithms in parallel on HPC systems while abstracting implementation details from end user.

The sampling from proposal distributions and computations of (unnormalized) particles weights can be computed independently in parallel for each particle.
"""

# ╔═╡ 8bf0deda-bcf3-439d-87ef-df223a0a2615
md"""
## 🖧 Processor hierarchies

Modern high-performance computing systems have complex hierarchies of processing elements.

Communication costs between processing elements in different levels vary, with interconnects of various bandwidths at higher levels and communication between shared memory at lower levels.

To be able to achieve good parallelisation performance we need to be able to tune how our computational task is distributed across the processing elements.
"""

# ╔═╡ 2a8edfdf-a227-4c82-b5dd-1c9386e28daf
md"""
## 🖧 Example: ARCHER2

ARCHER2, the UK national supercomputer, has 5860 compute nodes which can communicate over a fast interconnect, with each node hosting two processors.
"""

# ╔═╡ 39864a73-8122-42f1-8228-137b30b17e29
mermaid"""
%%{init: {'theme': '$selected_theme'}}%%
graph LR
  classDef invisible fill:#0000,color:#0000,stroke:#0000
  subgraph node0[Node]
    direction LR
    node0socket0[Processor]
    node0socket1[Processor]
  end
  subgraph node1[Node]
     direction LR
     node1socket0[Processor]
     node1socket1[Processor]
  end
  dummy0:::invisible -.- node0socket0 === node0socket1 --- node1socket0 === node1socket1 -.- dummy1:::invisible
"""

# ╔═╡ a459a494-4ff8-4fb2-8dd3-cb50a71b224d
md"""
Each processor in turn contains 4 non-uniform memory access (NUMA) regions....
"""

# ╔═╡ aa567e17-3691-43d4-9515-25d3ac3436f1
mermaid"""
%%{init: {'theme': '$selected_theme'}}%%
graph
  subgraph Processor
    direction TB
    n0[NUMA region]
    n1[NUMA region]
    n2[NUMA region]
    n3[NUMA region]
  end
"""

# ╔═╡ 24f53572-2db2-47d5-9fbe-49cfd6e6ebec
md"""
## 🖧 Example: ARCHER2

... each NUMA region in turn contains 2 core-complex dies (CCDs) ....
"""

# ╔═╡ 36257f78-261a-402c-acb2-d82d7836382d
mermaid"""
%%{init: {'theme': '$selected_theme'}}%%
graph
  subgraph NUMA region
    direction TB
    ccd0[CCD]
    ccd1[CCD]
  end
"""

# ╔═╡ b6620cd9-8501-4967-b7d8-ea3ab495656d
md"""
... each CCD in turn contains 2 core-complexes (CCXs) ....
"""

# ╔═╡ 763cf7ae-a823-4fb0-a663-1dafa8dc898d
mermaid"""
%%{init: {'theme': '$selected_theme'}}%%
graph
  subgraph CCD
    direction TB
    ccx0[CCX]
    ccx1[CCX]
  end
"""

# ╔═╡ 7cfbd7cd-a1d6-497a-bee1-381f9bc32304
md"""
## 🖧 Example: ARCHER2

... and finally each CCX in turn contains 4 cores.
"""

# ╔═╡ 00314d58-fce2-4a05-88ab-5d223c328be7
mermaid"""
%%{init: {'theme': '$selected_theme'}}%%
graph
  subgraph CCX
    direction TB
    c0[Core]
    c1[Core]
    c2[Core]
    c3[Core]
  end
"""

# ╔═╡ f30d8c39-8e11-46b1-b03b-6efd9ff12028
md"""
In total each ARCHER2 node therefore has ``2 \times 4 \times 2 \times 2 \times 4 = 128`` cores, however the cost of communicating between cores in each of the different levels differs. In general cores grouped together at a lower level will have lower communication cost.
"""

# ╔═╡ 89a1e26d-2cdd-4b6e-8c4e-8136f5195937
md"""
## 🗃️ Hierarchical parallelism model

ParticleDA.jl allows operations to be parallelised both over multiple processing elements sharing memory on a single node (for example CPU cores) and processing elements distributed over multiple nodes (each potentially consisting of multiple processing elements) in a cluster.

Operations are parallelized across multiple threads on shared memory systems using the native task-based multi-threading support in Julia.

In distributed memory environments ParticleDA.jl allows parallelizing across processes (ranks) with communication between processes controlled using a _message passing interface_ (MPI) implementation.

"""

# ╔═╡ 523270f2-b099-40eb-92f3-1532f1c1ceb8
md"""
## 🗃️ Hierarchical parallelism model
"""

# ╔═╡ 6d9b3093-ae8b-482e-9bf4-be104ecd78b8
mermaid"""
%%{init: {'theme': '$selected_theme'}}%%
graph
  subgraph fa:fa-microchip Rank 2
    subgraph fa:fa-square-check Task 0
      p16["fa:fa-circle Particle 16"]
      p17["fa:fa-circle Particle 17"]
    end
    subgraph fa:fa-square-check Task 1
      p18["fa:fa-circle Particle 18"]
      p19["fa:fa-circle Particle 19"]
    end
    subgraph fa:fa-square-check Task 2
      p20["fa:fa-circle Particle 20"]
      p21["fa:fa-circle Particle 21"]
    end
    subgraph fa:fa-square-check Task 3
      p22["fa:fa-circle Particle 22"]
      p23["fa:fa-circle Particle 23"]
    end
  end
  subgraph fa:fa-microchip Rank 1
    subgraph fa:fa-square-check Task 0
      p8["fa:fa-circle Particle 8"]
      p9["fa:fa-circle Particle 9"]
    end
    subgraph fa:fa-square-check Task 1
      p10["fa:fa-circle Particle 10"]
      p11["fa:fa-circle Particle 11"]
    end
    subgraph fa:fa-square-check Task 2
      p12["fa:fa-circle Particle 12"]
      p13["fa:fa-circle Particle 13"]
    end
    subgraph fa:fa-square-check Task 3
      p14["fa:fa-circle Particle 14"]
      p15["fa:fa-circle Particle 15"]
    end
  end
  subgraph fa:fa-microchip Rank 0
    subgraph fa:fa-square-check Task 0
      p0["fa:fa-circle Particle 0"]
      p1["fa:fa-circle Particle 1"]
    end
    subgraph fa:fa-square-check Task 1
      p2["fa:fa-circle Particle 2"]
      p3["fa:fa-circle Particle 3"]
    end
    subgraph fa:fa-square-check Task 2
      p4["fa:fa-circle Particle 4"]
      p5["fa:fa-circle Particle 5"]
    end
    subgraph fa:fa-square-check Task 3
      p6["fa:fa-circle Particle 6"]
      p7["fa:fa-circle Particle 7"]
    end
  end
"""

# ╔═╡ 5f515951-61a4-4265-9a68-9b142508bcb5
md"""
## 🔁 Filtering loop communication
"""

# ╔═╡ bb7c45eb-56d3-46c1-91aa-243972122405
mermaid"""
%%{ init: { 'flowchart': { 'curve': 'linear' }, 'theme':'$selected_theme'} }%%

graph BT

  classDef invisible fill:#fff0,stroke:#fff,stroke-width:0px,color:#fff0;
  subgraph Rank 0

    direction LR
    sp0[["`Sample proposals & compute weights`"]]
    gw0["`Gather weights`"]
    ri0["`Resample indices`"]
    bi0["`Broadcast indices`"]
    cs0["`Copy states`"]
    us0[["`Update statistics`"]]
    ws0["`Write outputs`"]
  end

  subgraph Rank 1:R-1
    direction TB
    sp1[["`Sample proposals & compute weights`"]]
    gw1["`Gather weights`"] <-.-> gw0
    bi1["`Broadcast indices`"] <-.-> bi0
    cs1["`Copy states`"] <-.-> cs0
    us1[["`Update statistics`"]] <-.-> us0
    in1["......................"]:::invisible ~~~ ws0
  end
"""

# ╔═╡ 2f8496ff-69ed-4455-9775-3fbeba384a1c
md"""
# 🌊 Tsunami model example

Linearization of shallow water equations with additive state noise corresponding to Gaussian random fields with Matérn covariance function.

Surface height field assumed to be observed at sparse set of observation stations with Gaussian observation noise.
"""

# ╔═╡ 85e996e6-5f42-43f5-a26d-764c4e20b691
html"<p style='text-align: center; font-family: Computer Modern'>Estimated mean</p>"

# ╔═╡ ced58824-39bd-41c8-8ea5-2298657a6f31
md"## 🌊 ARCHER2 weak scaling results"

# ╔═╡ a3051e6a-2ca8-477f-ac8b-61b754e4a445
LocalResource("tsunami-weak-scaling-$(selected_theme).svg", :width => 550)

# ╔═╡ 785ab1a5-fc45-4185-85d9-b88d9a9d4dd1
md"""
# ☔ Weather model example

_Simplified parameterizations primitive equation dynamics_ (SPEEDY) - an intermediate complexity atmospheric general circulation model.

We wrapped a Fortran 90 translation (<https://samhatfield.co.uk/speedy.f90>) using file based input-output and augmented with additive state noise corresponding to Gaussian random fields.

Future plan is to move to more flexible native Julia reimplementation _SpeedyWeather_ (<https://speedyweather.github.io/>).

"""

# ╔═╡ 09a2f97b-783a-4723-a6e2-fb53aa9ceda3
md" ## ☔ Surface pressure estimation"

# ╔═╡ 3da6554e-033a-4a8c-915f-b1304baaf7a8
LocalResource("speedy-results-$(selected_theme)-1.svg")

# ╔═╡ 596f73b6-5f78-48dd-8884-6165a709ccdb
md" ## ☔ Surface pressure estimation"

# ╔═╡ 26b2155b-0fe0-412b-94ab-50a7713381eb
LocalResource("speedy-results-$(selected_theme)-2.svg")

# ╔═╡ 77e40a4d-68ee-4bdb-b1a9-0326b8d22492
md"""
# ✅ Conclusions

ParticleDA.jl is a flexible Julia package for performing particle-filter based data assimilation.

High-level interface makes it simple for end-users to apply and for developers to extend the package.

A versatile two-level parallelism model is supported to allow running at scale on HPC systems.

A key aim is adding support for spatially localised filters.
"""

# ╔═╡ 72eaf64e-e9c9-482f-80c0-cfaa1b9ac8cc
md"""
# 🙏 Acknowledgements and links

ParticleDA.jl development was supported by the _Real-time Advanced Data Assimilation for Digital Simulaton of numerical twins on HPC_ (RADDISH) and _Advanced Quantification of Uncertainties In Fusion modelling at the Exascale with model order Reduction_ (AQUIFER) projects.

💻 Code: <https://github.com/Team-RADDISH/ParticleDA.jl>  \
📄Pre-print: <https://gmd.copernicus.org/preprints/gmd-2023-38/>

##

##
"""

# ╔═╡ 11ef29c6-5b43-412b-ad57-9cf25f72405f
Lorenz63 = @ingredients("../../test/models/lorenz63.jl").Lorenz63

# ╔═╡ b001bd63-6bb9-4f35-a062-c6cdb7956a43
LLW2d = @ingredients("../../test/models/llw2d.jl").LLW2d

# ╔═╡ aa12dc4e-4dd0-4963-88c0-3cd01b279f70
function set_plot_style(selected_theme)
	theme(selected_theme)
	default(
		fontfamily="Computer Modern",
		linewidth=2, 
		framestyle=:box, 
		label=nothing, 
		grid=true,
		background_color="transparent",
		background_color_subplot="transparent",
		background_color_inside="transparent",
	)
end

# ╔═╡ 15652fdd-df05-4bf1-ae37-fae0aa518847
const simulation_seed = 20230718;

# ╔═╡ 66d63209-2bb5-4fbe-98d2-3eefb12cb15b
const filtering_seed = 20230719;

# ╔═╡ f047eb91-9438-4963-b742-a7bf9bb58f34
const lorenz_max_time_step = 100;

# ╔═╡ 78d12cb9-6541-42cd-a822-2e902bcd2d19
md"""
## 🦋 Lorenz system example

Timestep $(@bind lorenz_simulation_time_step Slider(0:lorenz_max_time_step; default=0, show_value=true))
"""

# ╔═╡ 6c419d08-7db9-4f2f-8f17-745be650cad1
const lorenz_model_dict = Dict(
	"observation_noise_std" => 1., 
	"initial_state_std" => 1.,
	"state_noise_std" => 1.,
	"observed_indices" => [1, 2],
);

# ╔═╡ 315a4db6-0fff-40dc-9a1d-e816768b5a07
lorenz_state_sequence, lorenz_observation_sequence = let
	rng = Random.TaskLocalRNG()
	Random.seed!(rng, simulation_seed)
	model = Lorenz63.init(lorenz_model_dict)
	states = Matrix{ParticleDA.get_state_eltype(model)}(
		undef, 
		lorenz_max_time_step + 1, 
		ParticleDA.get_state_dimension(model)
	)
	observations = Matrix{ParticleDA.get_observation_eltype(model)}(
		undef,
		lorenz_max_time_step,
		ParticleDA.get_observation_dimension(model)
	)
	ParticleDA.sample_initial_state!(view(states, 1, :), model, rng)
	for t in 1:lorenz_max_time_step
		states[t + 1, :] .= view(states, t, :)
		state, observation = view(states, t + 1, :), view(observations, t, :)
		ParticleDA.update_state_deterministic!(state, model, t)
		ParticleDA.update_state_stochastic!(state, model, rng)
		ParticleDA.sample_observation_given_state!(observation, state, model, rng)
	end
	(states, observations)
end;

# ╔═╡ 96590fae-406e-4a2d-97b3-ceee0d5e9324
let
	set_plot_style(selected_theme)
	state_plot = plot3d(
		eachcol(
			view(lorenz_state_sequence, 1:lorenz_simulation_time_step+1, :)
		)...,
	    xlim = (-30, 30),
	    ylim = (-30, 30),
	    zlim = (-10, 60),
	    legend = false,
		xlabel = L"x_1",
		ylabel = L"x_2",
		zlabel = L"x_3",
	    marker = 2,
		linewidth = 1.,
		margin = -20px,
	)
	observation_plot = plot(
		eachcol(
			view(lorenz_observation_sequence, 1:lorenz_simulation_time_step, :)
		)...,
		xlim=(-30, 30), 
		ylim=(-30, 30), 
		legend=false,
		xlabel=L"y_1", 
		ylabel=L"y_2",
		aspectratio=1,
		linewidth = 1.,
		marker=2,
	)
	plot(state_plot, observation_plot, size=(600, 300))
end

# ╔═╡ a1dcff70-6686-401a-a4ca-fc85df12b3ff
let
	set_plot_style(selected_theme)
	n_time_step = lorenz_filtering_control ÷ 2
	show_pre_resampling = (lorenz_filtering_control) % 2 == 0
	rng = Random.TaskLocalRNG()
	Random.seed!(rng, filtering_seed)
	model = Lorenz63.init(lorenz_model_dict)
	states = ParticleDA.init_states(model, lorenz_n_particle, 1, rng)
	resampled_states = copy(states)
	log_weights = ones(lorenz_n_particle)
	particle_indices = Vector{Int}(undef, lorenz_n_particle)
	state_plot = plot3d(
		2,
	    xlim = (-25, 25),
	    ylim = (-25, 25),
	    zlim = (-5, 50),
	    legend = false,
		xlabel = L"x_1",
		ylabel = L"x_2",
		zlabel = L"x_3",
	    marker = [2 0],
        linewidth = [1. 1.],
		margin=-10px,
	)
	for (t, (observation, true_state)) in enumerate(
		zip(
			eachrow(view(lorenz_observation_sequence, 1:n_time_step, :)),
			eachrow(view(lorenz_state_sequence, 2:n_time_step + 1, :))
		)
	)
		states .= resampled_states
		for (p, state) in enumerate(eachcol(states))
			ParticleDA.update_state_deterministic!(state, model, t)
			ParticleDA.update_state_stochastic!(state, model, rng)
			log_weights[p] = ParticleDA.get_log_density_observation_given_state(
				observation, state, model
			)
		end
		weights = ParticleDA.normalized_exp!(log_weights)
		ParticleDA.resample!(particle_indices, weights, rng)
		resampled_states .= states[:, particle_indices]
		push!(state_plot, 1, mean(states, dims=2)[:, 1]...)
		push!(state_plot, 2, true_state...)
	end
	plot!(
		state_plot,
		eachrow(show_pre_resampling ? states : resampled_states)...,
		linewidth=0,
		marker=1,
	)
	weights = show_pre_resampling ? log_weights : ones(lorenz_n_particle) / lorenz_n_particle
	weight_plot = plot(
		1:lorenz_n_particle,
		weights,
		xlim=(0, maximum(weights)),
		seriestype=:bar,
		orientation="h",
		linewidth=0,
		xticks=nothing,
		yticks=nothing,
		legend=false,
	)
	plot(
		state_plot,
		weight_plot,
		layout=grid(1, 2, widths=[0.9, 0.1]),
		size=(600, 300),
		dpi=100
	)
end

# ╔═╡ 5191447c-33d5-41d7-88f7-6f4267d5a804
const llw2d_max_time_step = 100;

# ╔═╡ 74d5fbbf-b092-4ca0-a420-6601c0319fa9
md"""
## 🌊 Simulation
Timestep $(@bind llwd_simulation_timestep Slider(1:llw2d_max_time_step; default=0, show_value=true))\
"""

# ╔═╡ cc348082-6f8f-4e32-be24-cf4f92a454a7
md"""
## 🌊 Filtering
Timestep $(@bind llwd_filtering_time_step Slider(0:llw2d_max_time_step; default=0, show_value=true))\
Num. particles $(@bind llwd_filtering_n_particle Slider(50:50:200; default=100, show_value=true))    
Proposal $(@bind llw2d_filter_type Select([OptimalFilter => "locally optimal", BootstrapFilter => "bootstrap"]))     
Zero mean initial height $(@bind llw2d_use_zero_mean_initial_height CheckBox())
"""

# ╔═╡ 82c61d87-5601-41e1-b214-053ca0dc301c
const llw2d_model_dict = Dict(
	"x_length" => 200.0e3,
	"y_length" => 200.0e3,
	"nx" => 81,
	"ny" => 81,
	"n_stations_x" => 5,
	"n_stations_y" => 5,
	"station_boundary_x" => 20e3,
	"station_boundary_y" => 20e3,
	"station_distance_x" => 30e3,
	"station_distance_y" => 30e3,
	"obs_noise_std" => [0.05],
	"nu" => 2.5,
	"lambda" => 5.0e3,
	"sigma" => [0.05, 0.5, 0.5],
	"nu_initial_state" => 2.5,
	"lambda_initial_state" => 5.0e3,
	"sigma_initial_state" => [0.5, 5., 5.],
	"n_integration_step" => 10,
	"time_step" => 10.,
	"peak_height" => 30.0,
	"peak_position" => [1e4, 1e4],
	"observed_state_var_indices" => [1],
	"use_peak_initial_state_mean" => true,
	"padding" => 0,
);

# ╔═╡ 0c2b2d50-036d-4e7b-8c48-b6637667c91c
const llw2d_model, llw2d_state_sequence, llw2d_observation_sequence = let
	rng = Random.TaskLocalRNG()
	Random.seed!(rng, simulation_seed)
	model = LLW2d.init(Dict("llw2d" => llw2d_model_dict))
	states = Matrix{ParticleDA.get_state_eltype(model)}(
		undef, 
		llw2d_max_time_step + 1, 
		ParticleDA.get_state_dimension(model)
	)
	observations = Matrix{ParticleDA.get_observation_eltype(model)}(
		undef,
		llw2d_max_time_step,
		ParticleDA.get_observation_dimension(model)
	)
	ParticleDA.sample_initial_state!(view(states, 1, :), model, rng)
	for t in 1:lorenz_max_time_step
		states[t + 1, :] .= view(states, t, :)
		state, observation = view(states, t + 1, :), view(observations, t, :)
		ParticleDA.update_state_deterministic!(state, model, t)
		ParticleDA.update_state_stochastic!(state, model, rng)
		ParticleDA.sample_observation_given_state!(observation, state, model, rng)
	end
	(model, states, observations)
end;

# ╔═╡ f0bfaed4-a194-41a0-b74c-c1302033b9f3
function plot_llw2d_state_fields(
	state;
	show_station_locations=true,
	size=(900, 320),
)
	fields = LLW2d.flat_state_to_fields(state, llw2d_model.parameters)
	boundary_size = (
		floor(Int, llw2d_model.parameters.absorber_thickness_fraction * llw2d_model.parameters.nx),
		floor(Int, llw2d_model.parameters.absorber_thickness_fraction * llw2d_model.parameters.ny)
	)
	index_1_range = boundary_size[1]:llw2d_model.parameters.nx-boundary_size[1]
    index_2_range = boundary_size[2]:llw2d_model.parameters.ny-boundary_size[2]
	plots = [
		heatmap(
			field[index_1_range, index_2_range],
			aspect_ratio=:equal,
			clims=(-scale, scale),
			xticks=nothing,
			yticks=nothing,
			cmap=:deep,
			legend=:none,
			title=label,
			xlims=(1, length(index_1_range)),
			ylims=(1, length(index_2_range)),
		)
		for (field, label, scale) in zip(
			eachslice(fields, dims=3), 
			("Surface height", "Velocity component 1", "Velocity component 2"),
			(3, 300, 300),
		)
	]
	if show_station_locations
		station_grid_indices = LLW2d.get_station_grid_indices(llw2d_model.parameters)
		for observed_index in llw2d_model.parameters.observed_state_var_indices
			scatter!(
				plots[observed_index],
				eachcol(station_grid_indices)...,
				xlims=(1, length(index_1_range)),
				ylims=(1, length(index_1_range)),
				marker=2
			)
		end
	end
	plot(plots..., layout=grid(1, 3), size=size)
end

# ╔═╡ 8a2644ce-b3a1-4efc-91ed-0d62047358a3
let
	set_plot_style(selected_theme)
	state = view(llw2d_state_sequence, llwd_simulation_timestep + 1, :)
	plot_llw2d_state_fields(state)
end

# ╔═╡ decb2b80-93ee-4d63-8bc4-2f83384383a4
function fields_to_state_vector(group)
	vcat((vec(read(group, key)) for key in ("height", "vx", "vy"))...)
end

# ╔═╡ beded2b9-314e-431a-bef5-7bae94d3bcba
llw2d_state_mean_sequence, llw2d_state_var_sequence, llw2d_weight_sequence = begin
	output_filename = tempname()
	rng = Random.TaskLocalRNG()
	Random.seed!(rng, filtering_seed)
	llw2d_model_dict_adjusted = copy(llw2d_model_dict)
	llw2d_model_dict_adjusted["use_peak_initial_state_mean"] = !llw2d_use_zero_mean_initial_height
	model_parameters_dict = Dict("llw2d" => llw2d_model_dict_adjusted)
	filter_parameters = ParticleDA.FilterParameters(
		nprt=llwd_filtering_n_particle,
		verbose=true,
		output_filename=output_filename,
	)
	isfile(output_filename) && rm(output_filename)
	particles, statistics = ParticleDA.run_particle_filter(
		LLW2d.init,
		filter_parameters,
		model_parameters_dict,
		llw2d_observation_sequence',
		llw2d_filter_type,
		ParticleDA.MeanAndVarSummaryStat;
		rng=rng
	)
	state_mean_seq = Matrix{ParticleDA.get_state_eltype(llw2d_model)}(
		undef, 
		llw2d_max_time_step + 1, 
		ParticleDA.get_state_dimension(llw2d_model)
	)
	state_var_seq = Matrix{ParticleDA.get_state_eltype(llw2d_model)}(
		undef, 
		llw2d_max_time_step + 1, 
		ParticleDA.get_state_dimension(llw2d_model)
	)
	weights_seq = Matrix{Float64}(
		undef, llw2d_max_time_step + 1, llwd_filtering_n_particle
	)
	h5open(output_filename, "r") do file
		for t in 0:llw2d_max_time_step
			key = ParticleDA.time_index_to_hdf5_key(t)
			state_mean_seq[t + 1, :] = fields_to_state_vector(file["state_avg"][key])
			state_var_seq[t + 1, :] = fields_to_state_vector(file["state_var"][key])
			weights_seq[t + 1, :] = read(file["weights"][key])
		end
	end
	state_mean_seq, state_var_seq, weights_seq
end;

# ╔═╡ 2d987546-e11a-4d01-9eaf-811c7f41fa79
begin
	set_plot_style(selected_theme)
	plot_llw2d_state_fields(
		view(llw2d_state_mean_sequence, llwd_filtering_time_step + 1, :);
	)
end

# ╔═╡ Cell order:
# ╟─aae05a0a-4744-47d1-819d-6f1c5bcff6b5
# ╟─b8026d26-2187-11ee-2234-f523a9788e24
# ╟─3d919910-a6bc-494d-9268-996fd5e02462
# ╟─452da1fa-dc84-4761-a0d7-8fd2c53647b6
# ╟─488b438e-779a-4259-812d-2e99c6fe1706
# ╟─33aacb01-43e6-4b7d-8950-c7bc72ed323c
# ╟─5e36d92f-db98-4a6a-bb35-c46fab896e34
# ╟─7748c722-8be1-4028-aee1-21814da9c7e4
# ╟─78d12cb9-6541-42cd-a822-2e902bcd2d19
# ╟─96590fae-406e-4a2d-97b3-ceee0d5e9324
# ╟─315a4db6-0fff-40dc-9a1d-e816768b5a07
# ╟─cb7735c5-3fa7-4e40-bcff-be9211497075
# ╟─927b3c9c-9c5d-4ed5-9dfd-51c47efeab9a
# ╟─a1dcff70-6686-401a-a4ca-fc85df12b3ff
# ╟─cdae6aaa-af2f-420c-8c30-cc2affe87297
# ╟─266d1b36-7e7d-484f-8802-121839291f29
# ╟─fdd17edb-8ed7-4399-b14e-7182755f4acd
# ╟─33caa202-a177-47f1-a252-94655c5ff5e2
# ╟─c110e393-0051-41ab-9381-acfab97d890a
# ╟─35163903-3c2c-4148-bab9-e31d8a9cb0d5
# ╟─a1eeb474-d9ad-4f7a-a8e2-9ddb4c526448
# ╟─51e87757-885e-4e6c-b940-b829b93d7949
# ╟─8bf0deda-bcf3-439d-87ef-df223a0a2615
# ╟─2a8edfdf-a227-4c82-b5dd-1c9386e28daf
# ╟─39864a73-8122-42f1-8228-137b30b17e29
# ╟─a459a494-4ff8-4fb2-8dd3-cb50a71b224d
# ╟─aa567e17-3691-43d4-9515-25d3ac3436f1
# ╟─24f53572-2db2-47d5-9fbe-49cfd6e6ebec
# ╟─36257f78-261a-402c-acb2-d82d7836382d
# ╟─b6620cd9-8501-4967-b7d8-ea3ab495656d
# ╟─763cf7ae-a823-4fb0-a663-1dafa8dc898d
# ╟─7cfbd7cd-a1d6-497a-bee1-381f9bc32304
# ╟─00314d58-fce2-4a05-88ab-5d223c328be7
# ╟─f30d8c39-8e11-46b1-b03b-6efd9ff12028
# ╟─89a1e26d-2cdd-4b6e-8c4e-8136f5195937
# ╟─523270f2-b099-40eb-92f3-1532f1c1ceb8
# ╟─6d9b3093-ae8b-482e-9bf4-be104ecd78b8
# ╟─5f515951-61a4-4265-9a68-9b142508bcb5
# ╟─bb7c45eb-56d3-46c1-91aa-243972122405
# ╟─2f8496ff-69ed-4455-9775-3fbeba384a1c
# ╟─74d5fbbf-b092-4ca0-a420-6601c0319fa9
# ╟─8a2644ce-b3a1-4efc-91ed-0d62047358a3
# ╟─0c2b2d50-036d-4e7b-8c48-b6637667c91c
# ╟─cc348082-6f8f-4e32-be24-cf4f92a454a7
# ╟─85e996e6-5f42-43f5-a26d-764c4e20b691
# ╟─2d987546-e11a-4d01-9eaf-811c7f41fa79
# ╟─ced58824-39bd-41c8-8ea5-2298657a6f31
# ╟─a3051e6a-2ca8-477f-ac8b-61b754e4a445
# ╟─785ab1a5-fc45-4185-85d9-b88d9a9d4dd1
# ╟─09a2f97b-783a-4723-a6e2-fb53aa9ceda3
# ╟─3da6554e-033a-4a8c-915f-b1304baaf7a8
# ╟─596f73b6-5f78-48dd-8884-6165a709ccdb
# ╟─26b2155b-0fe0-412b-94ab-50a7713381eb
# ╟─77e40a4d-68ee-4bdb-b1a9-0326b8d22492
# ╟─72eaf64e-e9c9-482f-80c0-cfaa1b9ac8cc
# ╠═bb4489cd-e360-40f9-950f-a9029127a97f
# ╠═11ef29c6-5b43-412b-ad57-9cf25f72405f
# ╠═b001bd63-6bb9-4f35-a062-c6cdb7956a43
# ╠═aa12dc4e-4dd0-4963-88c0-3cd01b279f70
# ╠═15652fdd-df05-4bf1-ae37-fae0aa518847
# ╠═66d63209-2bb5-4fbe-98d2-3eefb12cb15b
# ╠═f047eb91-9438-4963-b742-a7bf9bb58f34
# ╠═6c419d08-7db9-4f2f-8f17-745be650cad1
# ╠═5191447c-33d5-41d7-88f7-6f4267d5a804
# ╠═82c61d87-5601-41e1-b214-053ca0dc301c
# ╠═f0bfaed4-a194-41a0-b74c-c1302033b9f3
# ╠═decb2b80-93ee-4d63-8bc4-2f83384383a4
# ╠═beded2b9-314e-431a-bef5-7bae94d3bcba
