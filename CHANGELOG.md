# Changelog

## [1.5.2](https://github.com/BirdeeHub/shelua/compare/v1.5.1...v1.5.2) (2025-05-04)


### Bug Fixes

* **repr:** functions should fall back to posix version if not defined ([e579f38](https://github.com/BirdeeHub/shelua/commit/e579f386cda07eb2fe58e53ffc4e658d66309947))

## [1.5.1](https://github.com/BirdeeHub/shelua/compare/v1.5.0...v1.5.1) (2025-05-04)


### Bug Fixes

* **feature:** allow extra_cmd_results to be a function as well ([ff19a36](https://github.com/BirdeeHub/shelua/commit/ff19a363ec86fb7932f4b6a4ff278ef874097737))

## [1.5.0](https://github.com/BirdeeHub/shelua/compare/v1.4.0...v1.5.0) (2025-05-04)


### Features

* **BREAKING:** repr add_args function also gets access to opts ([7397dba](https://github.com/BirdeeHub/shelua/commit/7397dbab57148a29f99ad58666ed751649269c82))

## [1.4.0](https://github.com/BirdeeHub/shelua/compare/v1.3.2...v1.4.0) (2025-05-04)


### Features

* **feature:** allow to concatenate command results via .. ([2db9416](https://github.com/BirdeeHub/shelua/commit/2db94166a3b064865823a6bd4052eb88582c7425))

## [1.3.2](https://github.com/BirdeeHub/shelua/compare/v1.3.1...v1.3.2) (2025-05-03)


### Bug Fixes

* **feature:** allowed pre and post 5.2 run repr functions to return extra cmd results ([f046876](https://github.com/BirdeeHub/shelua/commit/f04687600451ac4c3f99f7d607386867d0087285))

## [1.3.1](https://github.com/BirdeeHub/shelua/compare/v1.3.0...v1.3.1) (2025-05-03)


### Bug Fixes

* **feature:** concat_cmd repr fn can now also return a message like single_stdin ([c85811e](https://github.com/BirdeeHub/shelua/commit/c85811e22d625f4f6d6d6e4042a4d524b06c71b3))

## [1.3.0](https://github.com/BirdeeHub/shelua/compare/v1.2.1...v1.3.0) (2025-05-02)


### Features

* **repr_options:** allow different backends to be added ([c9cb916](https://github.com/BirdeeHub/shelua/commit/c9cb916b800ad8fa3ae6c9073a82bb5df1d1facb))
* **repr_options:** allow different backends to be added ([e89caaa](https://github.com/BirdeeHub/shelua/commit/e89caaa7ee30e84e80074b92e33c58087535ce01))

## [1.2.1](https://github.com/BirdeeHub/shelua/compare/v1.2.0...v1.2.1) (2025-05-02)


### Bug Fixes

* **sh:** unnecessary stdin pipes bug ([3b200da](https://github.com/BirdeeHub/shelua/commit/3b200daafac5d121b4c1aa419b42b2859194a6a8))

## [1.2.0](https://github.com/BirdeeHub/shelua/compare/v1.1.1...v1.2.0) (2025-05-02)


### Features

* **pipes:** proper_pipes setting ([cb38130](https://github.com/BirdeeHub/shelua/commit/cb3813059460067ddad12749540c766ea41142a2))
* **pipes:** proper_pipes setting ([3da7bc8](https://github.com/BirdeeHub/shelua/commit/3da7bc871e4c29d38ccef57eede7114260102676))

## [1.1.1](https://github.com/BirdeeHub/shelua/compare/v1.1.0...v1.1.1) (2025-04-30)


### Bug Fixes

* **settings:** function form clone was wrong ([9639f64](https://github.com/BirdeeHub/shelua/commit/9639f648d7795778e7547c18ad84b930e88259d2))

## [1.1.0](https://github.com/BirdeeHub/shelua/compare/v1.0.7...v1.1.0) (2025-04-30)


### Features

* **settings:** improved how settings and cloning works ([4f4ac04](https://github.com/BirdeeHub/shelua/commit/4f4ac04837e5a77f82ae70c14cb39da0cb96135e))

## [1.0.7](https://github.com/BirdeeHub/shelua/compare/v1.0.6...v1.0.7) (2025-04-30)


### Bug Fixes

* **sh:** improve last fix ([f0ae73d](https://github.com/BirdeeHub/shelua/commit/f0ae73d84a59b9acae2783201e02c448f959cab8))

## [1.0.6](https://github.com/BirdeeHub/shelua/compare/v1.0.5...v1.0.6) (2025-04-30)


### Bug Fixes

* **sh:** fix last refactor mistake ([2781333](https://github.com/BirdeeHub/shelua/commit/2781333ce9ca270c2dba2f6901c2181888e4fa17))

## [1.0.5](https://github.com/BirdeeHub/shelua/compare/v1.0.4...v1.0.5) (2025-04-30)


### Bug Fixes

* **clone:** I broke clone ([8c14b6d](https://github.com/BirdeeHub/shelua/commit/8c14b6db6cd59f0783b1c0d9390b2b1bda7c3650))

## [1.0.4](https://github.com/BirdeeHub/shelua/compare/v1.0.3...v1.0.4) (2025-04-30)


### Bug Fixes

* **tmpfile:** use os.tmpname dont hardcode ([b26a59c](https://github.com/BirdeeHub/shelua/commit/b26a59c4b454ba9f845012dd8bad269e1ad8e190))

## [1.0.3](https://github.com/BirdeeHub/shelua/compare/v1.0.2...v1.0.3) (2025-04-30)


### Bug Fixes

* **pre5.2:** full rn just incase ([bd3abdd](https://github.com/BirdeeHub/shelua/commit/bd3abdd2cb25c07d3292b5917b07c1bc226ebee4))

## [1.0.2](https://github.com/BirdeeHub/shelua/compare/v1.0.1...v1.0.2) (2025-04-29)


### Bug Fixes

* **feature:** added transforms setting ([2179d92](https://github.com/BirdeeHub/shelua/commit/2179d92ff32ba7c9d7c45ddc448ca6291658f94d))

## [1.0.1](https://github.com/BirdeeHub/shelua/compare/v1.0.0...v1.0.1) (2025-04-29)


### Bug Fixes

* **feature:** sh() with no args returns settings set to modify (was previously an error) ([afeb8f1](https://github.com/BirdeeHub/shelua/commit/afeb8f16a4f68b4190c62fa8bc7caef1bafc2957))

## 1.0.0 (2025-04-29)


### Features

* **release:** initial release ([6deac7a](https://github.com/BirdeeHub/shelua/commit/6deac7a79aeb69214d5b8437f2013c597b02c207))


### Bug Fixes

* **readme:** release bump ([658acc5](https://github.com/BirdeeHub/shelua/commit/658acc567422d03d81d85485f1064e5f9e8bb4a2))
