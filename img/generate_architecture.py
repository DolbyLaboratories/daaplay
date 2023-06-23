#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import plantuml
pu = plantuml.PlantUML(url='http://www.plantuml.com/plantuml/img/', basic_auth={}, form_auth={}, http_opts={}, request_opts={})
pu.processes_file("architecture.txt", outfile="architecture.png", errorfile="error.txt")
