"use strict";const t=require("../../utils/request.js");exports.login=function(r){return t.post("/auth/login",r,{auth:!1,showError:!1})};
