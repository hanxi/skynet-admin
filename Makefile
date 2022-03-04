.PHONY: check restart start stop reload status

all: check

check:
	luacheck `find app -name '*.lua' | xargs` --ignore 212/self --no-max-code-line-length

restart:
	wlua stop
	sleep 3
	wlua start

status:
	@wlua status

start:
	wlua start

stop:
	wlua stop

reload:
	wlua reload
