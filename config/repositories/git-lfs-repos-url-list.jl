import Pkg

const GIT_LFS_REPO_URL_LIST = String[
    x["source_url"] for x in values(
        Pkg.TOML.parsefile("git-lfs-repos-src-dest-pairs.toml")
        )
    ]
