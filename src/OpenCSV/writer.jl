mutable struct Writer <: PSRI.AbstractWriter
    io::IOStream
    stages::Int
    scenarios::Int
    blocks::Int
    agents::Int
    isopen::Bool
    is_hourly::Bool
    path::String
    stage_type::PSRI.StageType
    initial_stage::Int
    initial_year::Int
end

PSRI.is_hourly(graf::Writer) = graf.is_hourly
PSRI.stage_type(graf::Writer) = graf.stage_type
PSRI.max_blocks(graf::Writer) = graf.blocks
PSRI.initial_stage(graf::Writer) = graf.initial_stage

function _build_agents_str(agents::Vector{String})
    agents_str = ""
    for ag in agents
        agents_str *= ag * ','
    end
    agents_str = chop(agents_str; tail = 1)
    return agents_str
end

function PSRI.open(
    ::Type{Writer},
    path::String;
    # mandatory
    blocks::Integer = 0,
    scenarios::Integer = 0,
    stages::Integer = 0,
    agents::Vector{String} = String[],
    unit::Union{Nothing, String} = nothing,
    # optional
    is_hourly::Bool = false,
    block_type::Integer = 1,
    scenarios_type::Integer = 1,
    stage_type::PSRI.StageType = PSRI.STAGE_MONTH, # important for header
    initial_stage::Integer = 1, #month or week
    initial_year::Integer = 1900,
    sequential_model::Bool = true,
)
    if !(0 <= block_type <= 3)
        error("block_type must be between 0 and 3, got $block_type")
    end
    if block_type == 0 && blocks != 1
        error("block_type = 0, requires blocks = 1, got blocks = $blocks")
    end
    if !(0 <= scenarios_type <= 1)
        error("scenarios_type must be between 0 and 1, got $scenarios_type")
    end
    if scenarios_type == 0 && scenarios != 1
        error("scenarios_type = 0, requires scenarios = 1, got scenarios = $scenarios")
    end
    if unit === nothing
        error("Please provide a unit string: unit = \"MW\"")
    end
    if stage_type == PSRI.STAGE_MONTH
        if !(0 < initial_stage <= 12)
            error("initial_stage must be between 1 and 12 for monthly files, got: $initial_stage")
        end
    elseif stage_type == PSRI.STAGE_WEEK
        if !(0 < initial_stage <= 52)
            error("initial_stage must be between 1 and 52 for monthly files, got: $initial_stage")
        end
    else
        error("Unknown stage_type")
    end
    if !(0 < initial_year <= 1_000_000_000)
        error("initial_year must be a positive integer, got: $initial_year")
    end
    if is_hourly
        if block_type == 0
            error("Hourly files cannot have block_type == 0")
        end
        if 0 < blocks && verbose_hour_block_check
            println("Hourly files will ignore block dimension")
        end
    else
        if !(0 < blocks < 1_000_000)
            error("blocks must be a positive integer, got: $blocks")
        end
    end
    if !(0 < scenarios < 1_000_000_000)
        error("scenarios must be a positive integer, got: $scenarios")
    end
    if !(0 < stages < 1_000_000_000)
        error("stages must be a positive integer, got: $stages")
    end
    if isempty(agents)
        error("empty agents vector")
    end

    dir = dirname(path)
    if !isdir(dir)
        error("Directory $dir does not exist.")
    end

    if !isempty(splitext(path)[2])
        error("file path must be provided with no extension")
    end

    # delete previous file or error if its open
    PSRI._delete_or_error(path)

    # Inicia gravacao do resultado
    FILE_PATH = normpath(path)

    # agents with name_length
    agents_with_name_length = _build_agents_str(agents)
    # save header
    io = open(FILE_PATH * ".csv", "w")
    Base.write(io, "Varies per block?       ,$block_type,Unit,$unit,$initial_stage,$initial_year\n")
    Base.write(io, "Varies per sequence?    ,$scenarios_type\n")
    Base.write(io, "# of agents             ,$(length(agents))\n")
    Base.write(io, "Stag,Seq.,Blck,$agents_with_name_length\n")
    
    return Writer(
        io,
        stages,
        scenarios,
        blocks,
        length(agents),
        true,
        is_hourly,
        path,
        stage_type,
        initial_stage,
        initial_year
    )
end

# TODO check next entry is in the correct order
function PSRI.write_registry(
    writer::Writer,
    data::Vector{Float64},
    stage::Integer,
    scenario::Integer = 1,
    block::Integer = 1,
) where T

    if !writer.isopen
        error("File is not in open state.")
    end

    if !(1 <= stage <= writer.stages)
        error("stage should be between 1 and $(io.stages)")
    end
    if !(1 <= scenario <= writer.scenarios)
        error("scenarios should be between 1 and $(writer.scenarios)")
    end
    if !(1 <= block <= PSRI.blocks_in_stage(writer, stage))
        error("block should be between 1 and $(writer.blocks)")
    end
    if length(data) != writer.agents
        error("data vector has length $(length(data)) and expected was $(writer.agents)")
    end
    str = ""
    str *= string(stage) * ','
    str *= string(scenario) * ','
    str *= string(block) * ','
    for d in data
        str *= string(d) * ','
    end
    str = chop(str; tail = 1) # remove last comma
    str *= '\n'
    Base.write(writer.io, str)
    return nothing
end

function PSRI.close(writer::Writer)
    Base.close(writer.io)
    writer.isopen = false
    return nothing
end
