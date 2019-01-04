package com.example.demo.controller;

import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class MyController {


    @RequestMapping("/hello/{name}")
    public Object sayHello(@PathVariable("name") String name) {
        return "hello " + name;
    }
}
