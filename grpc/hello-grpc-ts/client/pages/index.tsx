import type { NextPage } from "next";
import { useState, Fragment, ChangeEvent } from "react";

import type { UserApiResponse } from "./api/user";

const App: NextPage = () => {
    const [result, setResult] = useState<string>("");
    const [selectedId, setSelectedId] = useState<number>();

    const handleChange = async (e: ChangeEvent<HTMLInputElement>) => {
        const id = Number(e.currentTarget.value);
        setSelectedId(id);

        const res = await fetch("/api/user", {
            method: "POST",
            body: JSON.stringify({ id }),
        });

        const json: UserApiResponse = await res.json();

        if (json.ok) {
            const { user } = json;
            setResult(JSON.stringify(user));
        } else {
            const { code, details } = json.error;
            setResult(`Error! ${code}: ${details}`);
        }
    };

    return (
        <div>
            {[...Array(3)].map((_, index) => {
                const id = index + 1;
                return (
                    <Fragment key={id}>
                        <input
                            type="radio"
                            value={id}
                            onChange={handleChange}
                            checked={id === selectedId}
                        />
                        {id}{" "}
                    </Fragment>
                );
            })}
            <p>{result}</p>
        </div>
    );
};

export default App;