##### Beginning of file

module Utils # Begin submodule MirrorUpdater.Utils

__precompile__(true)

import ..Types

import ..package_directory

import Dates
import HTTP
import TimeZones

function default_repo_description(
        ;
        env::AbstractDict = ENV,
        from::Any = "",
        when::Any = Dates.now(TimeZones.localzone(),),
        time_zone::Dates.TimeZone = TimeZones.TimeZone("America/New_York"),
        by::Any = "",
        )::String

    _from::String = strip(string(from))
    from_string::String = ""
    if length(_from) == 0
        from_string = ""
    else
        from_string = string(
            " ",
            strip(string("from $(_from)",)),
            )
    end

    _when::String = ""
    date_time_string::String = ""
    if isa(when, TimeZones.ZonedDateTime)
        _when = strip(
            string(TimeZones.astimezone(when,time_zone,))
            )
    else
        _when = strip(
            string(when)
            )
    end
    if length(_when) == 0
        date_time_string = ""
    else
        date_time_string = string(
            " ",
            strip(string("on ",_when,)),
            )
    end

    by_string::String = ""
    _by::String = strip(
        string(by)
        )
    if length(_by) == 0
        by_string = ""
    else
        by_string = string(
            " ",
            strip(string("by ",_by,)),
            )
    end

    travis_string::String = ""
    if _is_travis_ci(env)
        TRAVIS_BUILD_NUMBER::String = strip(
            get(env, "TRAVIS_BUILD_NUMBER", "")
            )
        TRAVIS_JOB_NUMBER::String = strip(
            get(env, "TRAVIS_JOB_NUMBER", "")
            )
        TRAVIS_EVENT_TYPE::String = strip(
            get(env, "TRAVIS_EVENT_TYPE", "unknown-travis-event")
            )
        TRAVIS_BRANCH = strip(
            get(env, "TRAVIS_BRANCH", "unknown-branch")
            )
        TRAVIS_COMMIT = strip(
            get(env, "TRAVIS_COMMIT", "unknown-commit")
            )
        TRAVIS_PULL_REQUEST = strip(
            get(env,"TRAVIS_PULL_REQUEST","unknown-pull-request-number")
            )

        job_or_build_string::String = ""
        if length(TRAVIS_JOB_NUMBER) > 0
            job_or_build_string = string(
                " ",
                strip(string("job $(TRAVIS_JOB_NUMBER)")),
                )
        elseif length(TRAVIS_BUILD_NUMBER) > 0
            job_or_build_string = string(
                " ",
                strip(string("build $(TRAVIS_BUILD_NUMBER)")),
                )
        else
            job_or_build_string = ""
        end

        triggered_by_string::String = ""
        if lowercase(TRAVIS_EVENT_TYPE) == "push"
            triggered_by_string = string(
                " ",
                strip(
                    string(
                        ", triggered by the push of",
                        " commit \"$(TRAVIS_COMMIT)\"",
                        " to branch \"$(TRAVIS_BRANCH)\"",
                        )
                    ),
                )
        elseif lowercase(TRAVIS_EVENT_TYPE) == "pull_request"
            triggered_by_string = string(
                " ",
                strip(
                    string(
                        ", triggered by",
                        " pull request #$(TRAVIS_PULL_REQUEST)",
                        )
                    ),
                )
        elseif lowercase(TRAVIS_EVENT_TYPE) == "cron"
            triggered_by_string = string(
                " ",
                strip(
                    string(
                        ", triggered by Travis",
                        " cron job on",
                        " branch \"$(TRAVIS_BRANCH)\"",
                        )
                    ),
                )
        else
            triggered_by_string = string(
                " ",
                strip(
                    string(
                        ", triggered by Travis \"",
                        strip(TRAVIS_EVENT_TYPE),
                        "\" event on",
                        " branch \"$(TRAVIS_BRANCH)\"",
                        )
                    ),
                )
        end
        travis_string = string(
            " ",
            strip(
                string(
                    "via Travis",
                    job_or_build_string,
                    triggered_by_string,
                    )
                ),
            )
    else
        travis_string = ""
    end

    new_description::String = strip(
        string(
            "Last mirrored",
            from_string,
            date_time_string,
            by_string,
            travis_string,
            )
        )

    return new_description
end

function _url_exists(url::AbstractString)::Bool
    _url::String = strip(convert(String, url))
    result::Bool = try
        r = HTTP.request("GET", _url)
        @debug("HTTP GET request result: ", _url, r.status,)
        r.status == 200
    catch exception
        @debug(string("Ignoring exception"), exception,)
        false
    end
    if result
    else
        @debug(string("URL does not exist"), _url,)
    end
    return result
end

function command_ran_successfully!!(
        cmds::Base.AbstractCmd,
        args...;
        max_attempts::Integer = 10,
        max_seconds_per_attempt::Real = 540,
        seconds_to_wait_between_attempts::Real = 30,
        error_on_failure::Bool = true,
        )::Bool
    success_bool::Bool = false
    function _my_false()::Bool
        @debug(string("Dummy output to keep Travis from failing"))
        result::Bool = false
        return result
    end
    function _my_process_exited(process_arg)::Bool
        @debug(string("Dummy output to keep Travis from failing"))
        result = process_exited(process_arg)
        return result
    end
    for attempt = 1:max_attempts
        if success_bool
        else
            @debug(string("Attempt $(attempt)"))
            if attempt > 1
                timedwait(
                    () -> _my_false(),
                    float(seconds_to_wait_between_attempts);
                    pollint = float(1.0),
                    )
            end
            p = run(cmds, args...; wait = false,)
            timedwait(
                () -> _my_process_exited(p),
                float(max_seconds_per_attempt),
                pollint = float(1.0),
                )
            if process_running(p)
                success_bool = false
                try
                    kill(p, Base.SIGTERM)
                catch exception
                    @warn("Ignoring exception: ", exception)
                end
                try
                    kill(p, Base.SIGKILL)
                catch exception
                    @warn("Ignoring exception: ", exception)
                end
            else
                success_bool = try
                    success(p)
                catch exception
                    @warn("Ignoring exception: ", exception)
                    false
                end
            end
        end
    end
    if success_bool
        @debug(string("Command ran successfully."),)
    else
        if error_on_failure
            error(string("Command did not run successfully."),)
        else
            @warn(string("Command did not run successfully."),)
        end
    end
    return success_bool
end

function _is_travis_ci(
        a::AbstractDict = ENV,
        )::Bool
    ci::String = lowercase(
        strip(get(a, "CI", "false"))
        )
    travis::String = lowercase(
        strip(get(a, "TRAVIS", "false"))
        )
    continuous_integration::String = lowercase(
        strip(get(a, "CONTINUOUS_INTEGRATION", "false"))
        )
    ci_is_true::Bool = ci == "true"
    travis_is_true::Bool = travis == "true"
    continuous_integration_is_true::Bool = continuous_integration == "true"
    answer::Bool = ci_is_true &&
        travis_is_true &&
        continuous_integration_is_true
    return answer
end

function _get_git_binary_path()::String
    deps_jl_file_path = package_directory("deps", "deps.jl")
    if !isfile(deps_jl_file_path)
        error(
            string(
                "MirrorUpdater.jl is not properly installed. ",
                "Please run\nPkg.build(\"MirrorUpdater\")",
                )
            )
    end
    include(deps_jl_file_path)
    git::String = strip(string(git_cmd))
    run(`$(git) --version`)
    @debug(
        "git command: ",
        git,
        )
    return git
end

end # End submodule MirrorUpdater.Utils

##### End of file
