import { mount } from "svelte";
import "../app.css";
import Page from "./Home.svelte";

mount(Page, { target: document.getElementById("app") });
