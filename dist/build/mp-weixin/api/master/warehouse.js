"use strict";const e=require("../../utils/request.js");exports.getEnabledWarehouses=function(){return e.get("/master/warehouse",{page:1,pageSize:100,status:"ENABLE"},{showError:!1})};
