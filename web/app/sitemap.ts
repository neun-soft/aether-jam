import type { MetadataRoute } from "next";

const BASE = "https://aether.neunsoft.com";

export default function sitemap(): MetadataRoute.Sitemap {
  return ["", "/privacy", "/terms", "/support"].map((path) => ({
    url: `${BASE}${path}`,
    changeFrequency: "monthly",
    priority: path === "" ? 1 : 0.6,
  }));
}
